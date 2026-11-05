package club.librum.kviz

import club.librum.kviz.servisi.Push
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PushTest {
    @Test fun izazovVodiUSanduce() = assertEquals("sanduce", Push.ruta("izazov", null))

    @Test fun pratilacVodiNaProfil() = assertEquals("igrac/ab-12", Push.ruta("pratilac", "ab-12"))

    @Test fun losIdSeCisti() = assertEquals("igrac/ab12", Push.ruta("pratilac", "ab/../12"))

    @Test fun nepoznatoNigde() {
        assertNull(Push.ruta("nesto", "x"))
        assertNull(Push.ruta("pratilac", ""))
        assertNull(Push.ruta(null, null))
    }
}
