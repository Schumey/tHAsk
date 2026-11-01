// Erzeugt von tools/make_app_icon.py: Symbol `thask:logo` für die Seitenleiste von Home Assistant.
const ICONS = { logo: "M3.04 8.38L6.3 8.38A2.04 2.04 0 0 0 6.3 4.31L3.04 4.31A2.04 2.04 0 0 0 3.04 8.38ZM3.04 15.31L13.63 15.31A2.04 2.04 0 0 0 13.63 11.24L3.04 11.24A2.04 2.04 0 0 0 3.04 15.31ZM3.04 22.24L20.96 22.24A2.04 2.04 0 0 0 20.96 18.16L3.04 18.16A2.04 2.04 0 0 0 3.04 22.24ZM11.47 7.28L13.92 9.73A1.32 1.32 0 0 0 15.79 7.86L13.34 5.41A1.32 1.32 0 0 0 11.47 7.28ZM15.82 9.69L21.12 3.99A1.32 1.32 0 0 0 19.18 2.19L13.88 7.89A1.32 1.32 0 0 0 15.82 9.69Z" };
window.customIcons = window.customIcons || {};
window.customIcons.thask = {
  getIcon: async (name) => ({ path: ICONS[name] || ICONS.logo }),
  getIconList: async () => Object.keys(ICONS).map((name) => ({ name })),
};
