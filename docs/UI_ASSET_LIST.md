# Inventario visual

Todos los PNG de `assets/ui/` proceden de los modelos editables en `art/blender/`.
Tienen alfa, luz suave y la paleta definida en `art/blender/common.py`.

| Uso | Tamaño | Identificadores |
|---|---|---|
| Recursos e indicadores | 256 × 256 | wood, grain, fish, salt, salted_fish, coins, population, happiness |
| Categorías | 256 × 256 | category_housing, category_services, category_food, category_materials |
| Herramientas | 256 × 256 | select, demolish |
| Construcción | 512 × 512 | house, road, well, farm, lumber, fishery, saltery |
| Variantes y revisión del entorno | 512 × 512 | house_cottage, house_tall, warehouse, sailboat, rowboat, tree_oak, tree_cypress, citizen |

Las variantes de vivienda comparten función y coste. Sus diferencias son visuales.
Los recursos también tienen GLB editables para reutilizarlos como objetos 3D.
El HUD utiliza 21 PNG; la colección completa contiene 29 renders.

No se dibujan versiones provisionales si falta un archivo: la importación debe
pasar `tools/check_ui_assets.gd` y `tools/check_models.gd`.
El minimapa utiliza el estado real de la simulación. Costes, títulos, selección,
velocidad y controles se dibujan con los controles nativos del juego.
