// NB: Deze code is Copy-pasted uit de editor. De libraries zijn Custom voor de Microbit Editor
// Run de code niet hier, download het naar de Microbit, en test het zelf 
basic.showLeds(`
    . . . . .
    . # # # .
    . # # # .
    . # # # .
    . . . . .
    `)
makerbit.connectSerialMp3(DigitalPin.P13, DigitalPin.P14)
makerbit.setMp3Volume(30)
basic.forever(function () {
    if (input.acceleration(Dimension.Y) > 200) {
        makerbit.playMp3Track(randint(1, 3), 1)
    }
})
