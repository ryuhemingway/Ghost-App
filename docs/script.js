const tabs = document.querySelectorAll(".mode-tab");
const panels = document.querySelectorAll(".mode-preview");

tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    const mode = tab.dataset.mode;

    tabs.forEach((item) => {
      const isActive = item === tab;
      item.classList.toggle("active", isActive);
      item.setAttribute("aria-selected", String(isActive));
    });

    panels.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.panel !== mode);
    });
  });
});
