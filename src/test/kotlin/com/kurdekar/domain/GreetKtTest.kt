package com.kurdekar.domain

import kotlin.test.assertEquals
import kotlin.test.Test

class GreetKtTest {

    @Test
    fun greetTest() {
        assertEquals("Hello, Akash!", greet("Akash"))
        assertEquals("Hello!", greet())
    }
}