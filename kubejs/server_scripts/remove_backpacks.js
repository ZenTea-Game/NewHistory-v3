ServerEvents.recipes(event => {
    event.remove({ output: 'sophisticatedbackpacks:gold_backpack' });
    event.remove({ output: 'sophisticatedbackpacks:diamond_backpack' });
    event.remove({ output: 'sophisticatedbackpacks:netherite_backpack' });

    event.remove({ input: 'sophisticatedbackpacks:gold_backpack' });
    event.remove({ input: 'sophisticatedbackpacks:diamond_backpack' });
    event.remove({ input: 'sophisticatedbackpacks:netherite_backpack' });
});