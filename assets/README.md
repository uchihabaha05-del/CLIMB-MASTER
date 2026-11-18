# Набор препятствий (40 моделей)

Каждая модель: `имя.gltf` + `имя.bin` (геометрия, нормали, UV) и текстуры в `textures/`.
Файлы .gltf ссылаются на текстуры по относительному пути `textures/...` — не меняйте структуру папок.

- Единицы: метры, ось Y вверх. Низ модели лежит на y = 0, центр по X/Z.
- Текстуры 512x512, бесшовные: `*.jpg` — цвет, `*_normal.png` — карта нормалей.
- Материалы PBR (metallic/roughness) уже прописаны в glTF.
- Для физики используйте Mesh Collider (или разбейте крупные модели на выпуклые части).

## Список
Камни и природа: boulder_granite, boulder_mossy, rock_cluster, rock_arch, stalagmite_field, basalt_columns, ice_boulder, ice_spikes
Дерево: fallen_log, log_pile, stump_with_roots, broken_bridge, crate_stack, broken_ladder, seesaw_plank
Бетон и кирпич: brick_wall_ruin, concrete_pipe, concrete_pipe_lying, rebar_pillar, jersey_barrier, spiral_stairs
Металл и хлам: rusty_barrel, hazard_barrel, barrel_stack, tire_stack, monster_tire, pipe_bend, pipe_cluster, shipping_container, gas_cylinder
Необычные: giant_anchor, giant_gears, giant_screw, giant_chain, coil_spring, satellite_dish, church_bell, anvil_on_stump, bicycle_wheel, iron_cauldron

`preview.jpg` — контактный лист для быстрого просмотра.
