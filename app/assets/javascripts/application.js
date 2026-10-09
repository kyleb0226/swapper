// Ask for confirmation before submitting any form/button marked with data-confirm.
document.addEventListener("submit", (event) => {
  const form = event.target;
  const message = form.dataset.confirm || event.submitter?.dataset.confirm;
  if (message && !window.confirm(message)) event.preventDefault();
});

// "Select all" checkbox: <input type="checkbox" data-select-all="name-of-checkboxes">
document.addEventListener("change", (event) => {
  const name = event.target.dataset.selectAll;
  if (!name) return;
  document.querySelectorAll(`input[type=checkbox][name="${name}"]`).forEach((box) => {
    if (!box.closest("tr")?.hidden) box.checked = event.target.checked;
  });
});
