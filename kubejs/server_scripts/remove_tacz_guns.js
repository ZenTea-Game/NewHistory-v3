ServerEvents.recipes(event => {
  // Удаляем основные рецепты оружейных столов по их ID
  event.remove({ id: 'tacz:gun_smith_table' });
  event.remove({ id: 'tacz:workbench_a' });
  event.remove({ id: 'tacz:workbench_b' });
  event.remove({ id: 'tacz:workbench_c' });

  // Удаляем кастомные столы из других модов (если нужны)
  event.remove({ id: 'create_armorer:create_workbench' });
  event.remove({ id: 'immersive_armorer:workbench' });
  event.remove({ id: 'tacz:attachment_workbench' });
  event.remove({ id: 'tacz:ammo_workbench' });

  // Удаляем ВСЕ рецепты, где эти блоки используются как ингредиент (защита от остатков)
  event.remove({ input: 'tacz:gun_smith_table' });
  event.remove({ input: 'tacz:workbench_a' });
  event.remove({ input: 'tacz:workbench_b' });
  event.remove({ input: 'tacz:workbench_c' });
  event.remove({ input: 'create_armorer:create_workbench' });

});