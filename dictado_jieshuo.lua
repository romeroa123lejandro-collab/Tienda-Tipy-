require "import"
import "android.speech.RecognizerIntent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.Button"
import "com.androlua.LuaDialog"
import "android.content.Context"
import "android.content.Intent"
import "android.os.Vibrator"
import "android.media.AudioManager"
import "android.os.Environment"
import "java.io.File"
import "android.content.ClipData"
import "android.content.ClipboardManager"
import "android.view.accessibility.AccessibilityNodeInfo"
import "android.view.accessibility.AccessibilityEvent"

-- Lista de variantes de espa帽ol soportadas
local spanishVariants = {
    {code = "es-ES", name = "Espa帽ol de Espa帽a", bgColor = 0xFFFF0000, textColor = 0xFFFFFFFF},  -- Rojo, texto blanco
    {code = "es-MX", name = "Espa帽ol de M茅xico", bgColor = 0xFFFFFFFF, textColor = 0xFF000000},  -- Blanco, texto negro
    {code = "es-US", name = "Espa帽ol de Estados Unidos", bgColor = 0xFF0000FF, textColor = 0xFFFFFFFF}  -- Azul, texto blanco
}

-- Ruta del archivo para guardar la preferencia de idioma
local LANGUAGE_PREFERENCE_FILE = "/sdcard/瑙ｅ帇/Plugins/Alex dictado 4.0/language_preference.txt"

-- Funci贸n para crear la carpeta si no existe
function createFolderIfNotExists(path)
    local folder = File(path)
    if not folder.exists() then
        folder.mkdirs()  -- Crear la carpeta y sus subcarpetas si no existen
    end
end

-- Funci贸n para guardar la preferencia de idioma en un archivo
function saveLanguagePreference(languageCode)
    -- Crear la carpeta si no existe
    createFolderIfNotExists("/sdcard/瑙ｅ帇/Plugins/Alex dictado 4.0")

    local file = io.open(LANGUAGE_PREFERENCE_FILE, "w")
    if file then
        file:write(languageCode)
        file:close()
        service.speak("Idioma cambiado a " .. languageCode)
        selectedLanguage = languageCode  -- Actualizar variable global
        empezarEscuchar()  -- Reiniciar el dictado autom谩ticamente
    else
        service.speak("Error al guardar la preferencia de idioma. Verifica los permisos de escritura.")
        print("Error: No se pudo abrir el archivo para escritura.")
    end
end

-- Funci贸n para obtener la preferencia de idioma desde un archivo
function getLanguagePreference()
    local file = io.open(LANGUAGE_PREFERENCE_FILE, "r")
    if file then
        local languageCode = file:read("*a")
        file:close()
        return languageCode
    else
        return nil
    end
end

-- Funci贸n para mostrar la interfaz de selecci贸n de idioma
function showLanguageSelectionDialog()
    local layout = {
        LinearLayout,
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "fill",
        padding = "16dp",
        {
            TextView,
            text = "Bienvenidos al dictado por voz de Jieshuo Paraguay 馃幉",
            textSize = "20sp",
            gravity = "center",
            layout_width = "fill",
            layout_height = "wrap_content",
            paddingBottom = "16dp"
        },
        {
            TextView,
            text = "Seleccione una variante de espa帽ol:",
            textSize = "16sp",
            gravity = "center",
            layout_width = "fill",
            layout_height = "wrap_content",
            paddingBottom = "16dp"
        }
    }

    -- Agregar botones para cada variante de espa帽ol
    for i, variant in ipairs(spanishVariants) do
        table.insert(layout, {
            Button,
            id = "button" .. i,
            text = variant.name,
            layout_width = "fill",
            layout_height = "wrap_content",
            backgroundColor = variant.bgColor,
            textColor = variant.textColor,
            padding = "8dp"
        })
    end

    -- Crear el cuadro de di谩logo
    local dlg = LuaDialog(service)
    dlg.setTitle("Selecci贸n de idioma")
    dlg.setView(loadlayout(layout))
    dlg.show()

    -- Asignar acciones a los botones
    for i, variant in ipairs(spanishVariants) do
        _G["button" .. i].onClick = function()
            dlg.dismiss()
            saveLanguagePreference(variant.code) -- Guarda y reinicia el dictado
        end
    end
end

-- Funci贸n para copiar texto al portapapeles
function copyToClipboard(text)
    local clipboard = service.getSystemService(Context.CLIPBOARD_SERVICE)
    local clip = ClipData.newPlainText("Texto reconocido", text)
    clipboard.setPrimaryClip(clip)
    service.speak("Texto copiado al portapapeles.")
end

-- Funci贸n para manejar comandos de voz
function handleVoiceCommand(command)
    if command == "cambiar variable" then
        showLanguageSelectionDialog()
        return
    end

    local textToInsert = {
        ["nueva l铆nea"] = "\n",
        ["nuevo p谩rrafo"] = "\n\n",
        ["copiar texto"] = function()
            local nodo = service.getEditText()
            if nodo then
                local texto = nodo.getText().toString()
                copyToClipboard(texto)
            else
                service.speak("No hay un cuadro de texto presente.")
            end
        end,
        ["punto"] = ".",
        ["coma"] = ",",
        ["signo de interrogaci贸n"] = "?",
        ["signo de exclamaci贸n"] = "!",
        ["dos puntos"] = ":",
        ["punto y coma"] = ";",
        ["guion"] = "-",
        ["guion bajo"] = "_",
        ["barra vertical"] = "|",
        ["barra diagonal"] = "/",
        ["asterisco"] = "*",
        ["par茅ntesis abrir"] = "(",
        ["par茅ntesis cerrar"] = ")",
        ["comillas dobles"] = '"',
        ["comillas simples"] = "'"
    }

    local action = textToInsert[command]
    if action then
        if type(action) == "function" then
            action() -- Ejecutar funci贸n especial (ej. copiar texto)
        else
            local nodo = service.getEditText()
            if nodo then
                service.insertText(nodo, action)
                service.speak("Comando ejecutado: " .. command)
            else
                service.speak("No hay un cuadro de texto presente.")
            end
        end
    else
        -- Insertar texto normal
        local nodo = service.getEditText()
        if nodo then
            service.insertText(nodo, command .. " ")
            service.speak("Texto insertado: " .. command)
        else
            service.speak("No hay un cuadro de texto presente.")
        end
    end
end

-- Funci贸n para vibrar (solo en modo de vibraci贸n o silencio)
function vibrate()
    local audioManager = service.getSystemService(Context.AUDIO_SERVICE)
    local mode = audioManager.getRingerMode()
    if mode == AudioManager.RINGER_MODE_VIBRATE or mode == AudioManager.RINGER_MODE_SILENT then
        local vibrator = service.getSystemService(Context.VIBRATOR_SERVICE)
        if vibrator and vibrator.hasVibrator() then
            vibrator.vibrate(100)  -- Vibra durante 100 milisegundos
        end
    end
end

-- Funci贸n para enfocar el cuadro de texto
function focusEditText(nodo)
    if nodo then
        nodo.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
    end
end

-- Funci贸n para empezar a escuchar
function empezarEscuchar()
    local nodo = service.getEditText()
    if not nodo then
        service.speak("No hay un cuadro de texto presente.")
        return
    end

    -- Enfocar el cuadro de texto autom谩ticamente
    focusEditText(nodo)

    -- Vibrar al iniciar el dictado
    vibrate()

    -- Crear el Intent para el reconocimiento de voz
    local intentReconocimiento = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    intentReconocimiento.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    intentReconocimiento.putExtra(RecognizerIntent.EXTRA_LANGUAGE, selectedLanguage or "es-ES")
    intentReconocimiento.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, service.getPackageName())

    -- Ajustar par谩metros para ignorar el ruido de fondo
    intentReconocimiento.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000)  -- 3 segundos de silencio con ruido
    intentReconocimiento.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000)  -- 2 segundos de silencio completo

    -- Crear el reconocedor de voz
    local reconocedorDeVoz = SpeechRecognizer.createSpeechRecognizer(service)

    -- Definir el oyente de voz
    local oyenteDeVoz = luajava.createProxy("android.speech.RecognitionListener", {
        onResults = function(resultados)
            local datos = resultados.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if datos and datos.size() > 0 then
                handleVoiceCommand(datos.get(0):lower())
            else
                service.speak("No se reconoci贸 ninguna palabra.")
            end
            -- Vibrar al finalizar el dictado
            vibrate()
        end,
        onError = function(error)
            service.speak("Error en el reconocimiento de voz: " .. tostring(error))
            -- Vibrar al finalizar el dictado
            vibrate()
        end
    })

    -- Configurar el oyente y comenzar a escuchar
    reconocedorDeVoz.setRecognitionListener(oyenteDeVoz)
    reconocedorDeVoz.startListening(intentReconocimiento)
end

-- Obtener la preferencia de idioma guardada
selectedLanguage = getLanguagePreference()

-- Iniciar el complemento
if not selectedLanguage then
    showLanguageSelectionDialog()
else
    empezarEscuchar()
end