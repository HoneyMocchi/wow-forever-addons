# Third-party libraries

ForeverThreat bundles the following libraries so users do not need to install BugSack,
Ace3, LibDBIcon or LibDataBroker separately.

- LibStub — public domain.
- CallbackHandler-1.0 — WowAce/Ace3 library.
- LibDataBroker-1.1 — WoW library by tekkub and contributors.
- LibDBIcon-1.0 — current lightweight minimap-button library used by many WoW addons.

The bundled LibDBIcon implementation follows the modern BugSack/LibDBIcon behavior:
it calculates the minimap edge from the actual Minimap width/height and supports
GetMinimapShape(), instead of using ForeverThreat's old custom fixed-radius code.

Upstream references:
- https://www.curseforge.com/wow/addons/libdbicon-1-0
- https://github.com/tekkub/libdatabroker-1-1
