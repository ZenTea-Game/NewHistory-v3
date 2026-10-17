// Оружие из TaCZ и обоих Armorer-паков изготавливается через Mechanical Crafter.
// Штатные рецепты Ammo Box заменены рецептами All of Aeronautics.
ServerEvents.recipes(event => {
  // Обычные рецепты TaCZ Ammo Box (дешёвые доски + слиток/алмаз).
  event.remove({ id: 'tacz:iron_ammo_box' });
  event.remove({ id: 'tacz:gold_ammo_box' });
  event.remove({ id: 'tacz:diamond_ammo_box' });

  // Убираем штатный простой рецепт оружейного стола; ниже он создаётся сборщиком.
  event.remove({ id: 'tacz:gun_smith_table' });

  // Эти обычные рецепты оружия заменены Mechanical Crafter-рецептами в KubeJS.
  event.remove({ id: /^tacz:gun\// });
  event.remove({ id: /^create_armorer:gun\// });
  event.remove({ id: /^immersive_armorer:gun\// });
  event.remove({ id: 'create_armorer:create_workbench' });
  event.remove({ id: 'immersive_armorer:workbench' });
});
