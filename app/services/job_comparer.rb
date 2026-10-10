require "json"

# Asks Claude whether pairs of job titles are similar enough for a location swap,
# and stores each answer in JobSimilarity. Only job titles, job codes and HR's job
# descriptions are sent; never employee names or other personal data.
class JobComparer
  MODEL = ENV.fetch("SWAPPER_AI_MODEL", "claude-opus-5-5")
  BATCH_SIZE = 25

  SCHEMA = {
    type: "object",
    properties: {
      results: {
        type: "array",
        items: {
          type: "object",
          properties: {
            pair: { type: "integer", description: "The pair number from the list" },
            score: { type: "integer", description: "0-100: how interchangeable the two jobs are" },
            reason: { type: "string", description: "One sentence an HR manager can read" }
          },
          required: %w[pair score reason],
          additionalProperties: false
        }
      }
    },
    required: %w[results],
    additionalProperties: false
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You help an HR team decide whether two employees with different job titles could trade work locations with
    each other: each would take over the other's position at the other site.

    For each pair of jobs, score 0-100 how interchangeable they are:
    - 90-100: the same job under different names or levels that do the same work (e.g. "RN" and "Registered Nurse").
    - 70-89: closely related; either person could do the other's job with little or no retraining, and no different
      license, certification or degree is required.
    - 40-69: related field, but meaningful differences in duties, required credentials, or seniority level.
    - 0-39: different jobs.
    Be conservative: a swap places someone into a real position, so differences in required licenses (e.g. RN vs LPN),
    supervisory vs non-supervisory roles, or specialty certifications should keep the score below 70.
    Use HR's job descriptions when provided; they take priority over what a title usually means.
    Give one plain sentence of reasoning per pair, written for an HR manager.
  PROMPT

  # Tests replace this with a lambda: ->(prompt) { [{ "pair" => 1, "score" => 90, "reason" => "..." }] }
  class_attribute :responder, default: nil

  def self.available?
    responder.present? || ENV["ANTHROPIC_API_KEY"].present?
  end

  def initialize(company)
    @company = company
  end

  # pairs: [[job_a_key, job_b_key], ...]. Returns the rows it updated.
  def compare(pairs)
    pairs.uniq.each_slice(BATCH_SIZE).flat_map { |batch| compare_batch(batch) }
  end

  private

  def compare_batch(batch)
    fingerprints = batch.to_h { |a, b| [ [ a, b ], JobSimilarity.fingerprint_for(@company, a, b) ] }
    results = request(prompt_for(batch)).index_by { |r| r["pair"].to_i }

    batch.each_with_index.map do |(job_a, job_b), index|
      row = @company.job_similarities.find_or_initialize_by(job_a: job_a, job_b: job_b)
      next row if row.manual?

      answer = results[index + 1]
      if answer
        score = answer["score"].to_i.clamp(0, 100)
        row.update!(status: "done", score: score, similar: score >= JobSimilarity::THRESHOLD, reason: answer["reason"].to_s.truncate(500),
                    fingerprint: fingerprints[[ job_a, job_b ]], model: MODEL, compared_at: Time.current)
      else
        row.update!(status: "failed", reason: "The AI didn't return an answer for this pair.", requested_at: Time.current)
      end
      row
    end
  rescue StandardError => e
    Rails.logger.error("[JobComparer] #{e.class}: #{e.message}")
    batch.map do |job_a, job_b|
      row = @company.job_similarities.find_or_initialize_by(job_a: job_a, job_b: job_b)
      row.update!(status: "failed", reason: "Comparison failed: #{e.message.truncate(200)}", requested_at: Time.current) unless row.manual?
      row
    end
  end

  def prompt_for(batch)
    keys = batch.flatten.uniq
    profiles = @company.job_profiles.where(title_key: keys).index_by(&:title_key)
    codes = @company.employees.where("LOWER(job_title) IN (?)", keys).where.not(job_code: [ nil, "" ])
                    .distinct.pluck(:job_title, :job_code)
                    .group_by { |title, _| JobProfile.key_for(title) }.transform_values { |rows| rows.map(&:last).uniq }

    describe = lambda do |key|
      profile = profiles[key]
      parts = [ "\"#{profile&.title || key}\"" ]
      parts << "codes: #{codes[key].join(", ")}" if codes[key].present?
      parts << "HR description: #{profile.description.squish}" if profile&.description.present?
      parts.join(" | ")
    end

    lines = batch.each_with_index.map { |(a, b), i| "#{i + 1}. #{describe.(a)}\n   vs #{describe.(b)}" }
    "Organization: #{@company.name}\n\nScore each pair:\n\n#{lines.join("\n\n")}"
  end

  def request(prompt)
    return Array(responder.call(prompt)) if responder

    client = Anthropic::Client.new
    message = client.beta.messages.create(
      model: MODEL,
      max_tokens: 16_000,
      system_: SYSTEM_PROMPT,
      messages: [ { role: "user", content: prompt } ],
      output_config: { effort: :low, format_: { type: :json_schema, schema: SCHEMA } },
      fallbacks: :default,
      betas: [ "server-side-fallback-2026-07-01" ]
    )
    raise "The AI declined to answer (#{message.stop_details&.category || "refusal"})" if message.stop_reason == :refusal
    raise "The AI's answer was cut off" if message.stop_reason == :max_tokens

    text = message.content.select { |block| block.type == :text }.map(&:text).join
    JSON.parse(text).fetch("results")
  end
end
