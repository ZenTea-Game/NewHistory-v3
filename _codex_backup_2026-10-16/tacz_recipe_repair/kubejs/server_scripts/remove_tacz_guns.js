ServerEvents.recipes(event => {
  // Убираем стандартные рецепты оружейных столов TaCZ.
  event.remove({ id: 'tacz:gun_smith_table' });
  event.remove({ id: 'tacz:workbench_a' });
  event.remove({ id: 'tacz:workbench_b' });
  event.remove({ id: 'tacz:workbench_c' });

  // Убираем остальные стандартные верстаки TaCZ, если для них есть рецепты.
  event.remove({ id: 'tacz:attachment_workbench' });
  event.remove({ id: 'tacz:ammo_workbench' });

  // Запрещаем использовать эти столы как ингредиенты в других рецептах.
  event.remove({ input: 'tacz:gun_smith_table' });
  event.remove({ input: 'tacz:workbench_a' });
  event.remove({ input: 'tacz:workbench_b' });
  event.remove({ input: 'tacz:workbench_c' });
});