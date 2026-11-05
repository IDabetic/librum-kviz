# R8 za izdanje (04.11.2026): bez njega je kod 45 MB (sve Material ikonice), AAB 17,7 MB.
# kotlinx.serialization: @Serializable klase čuvaju generisane serijalizatore (biblioteka nosi svoja pravila,
# ovo je osigurač za naše modele koji se čitaju iz JSON-a sa servera i iz assets).
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod
-keep,includedescriptorclasses class club.librum.kviz.**$$serializer { *; }
-keepclassmembers class club.librum.kviz.** {
    *** Companion;
}
-keepclasseswithmembers class club.librum.kviz.** {
    kotlinx.serialization.KSerializer serializer(...);
}
# Stanje partije (Osvajanje) se čuva kao JSON u SharedPreferences: imena polja moraju da ostanu ista.
-keepclassmembers @kotlinx.serialization.Serializable class club.librum.kviz.** { <fields>; }
# Pad aplikacije šalje stek u bazu: čitljiva imena linija.
-keepattributes SourceFile, LineNumberTable
