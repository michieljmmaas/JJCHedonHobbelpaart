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
        basic.showIcon(IconNames.Square)
        makerbit.playMp3Track(randint(1, 3), 1)
    }
    if (input.pinIsPressed(TouchPin.P0)) {
    	
    } else {
        basic.showIcon(IconNames.Heart)
        makerbit.playMp3Track(randint(4, 19), 1)
    }
    if (input.buttonIsPressed(Button.B)) {
        // Paardengeluid tracks 1-3 en Quotes tracks 4-19
        basic.showIcon(IconNames.EighthNote)
        makerbit.playMp3Track(randint(4, 19), 1)
    }
})
