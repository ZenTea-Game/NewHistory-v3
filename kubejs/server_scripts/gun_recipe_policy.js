// Огнестрельное оружие из TaCZ и Armorer изготавливается только в Mechanical Crafter.
// Боеприпасы, обвесы и прочие рецепты оружейного стола сохраняются.
ServerEvents.recipes(event => {
  event.remove({ id: /^tacz:gun\// });
  event.remove({ id: /^create_armorer:gun\// });
  event.remove({ id: /^immersive_armorer:gun\// });
  event.remove({ id: 'create_armorer:create_workbench' });
  event.remove({ id: 'immersive_armorer:workbench' });
});
