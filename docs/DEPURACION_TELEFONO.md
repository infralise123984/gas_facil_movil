# Depurar el teléfono y verlo en el PC

> Chuleta de trabajo para el S22 desde este PC (Windows, PowerShell 5.1).
> Verificado el 2026-10-07 con Flutter 3.47.6, adb 37.0.1 y scrcpy 5.0.

## 0. Rutas y datos fijos

| Qué | Dónde |
|---|---|
| `adb` | `C:\Users\tokyo-3\dev\android-sdk\platform-tools\adb.exe` |
| Flutter | `C:\Users\tokyo-3\dev\flutter\bin\flutter.bat` |
| scrcpy | `C:\Users\tokyo-3\dev\scrcpy\scrcpy.exe` |
| Proyecto | `C:\Users\tokyo-3\Desktop\proyecto\mobile` |
| Paquete de la app | `cl.kimgas.gas_facil_movil` |
| Teléfono | Samsung SM-S901E (S22), Android 16 |

**Regla de oro de PowerShell: nunca empieces un comando con `&`.** La consola de VS Code corta el `&` inicial y falla con `The ampersand (&) character is not allowed`. Guarda la ruta en una variable y úsala después:

```powershell
$a = 'C:\Users\tokyo-3\dev\android-sdk\platform-tools\adb.exe'
& $a devices
```

El teléfono y el PC tienen que estar en la **misma red wifi**.

---

## 1. Depurar por wifi (sin cable)

### 1.1 La primera vez: emparejar

En el teléfono: Ajustes → Opciones de desarrollador → **Depuración inalámbrica** → *Emparejar dispositivo con código*. Aparece un `IP:PUERTO` y un código de 6 dígitos.

```powershell
& $a pair 192.168.1.86:34279
# Escribe el código de 6 dígitos EN LA CONSOLA y pulsa Enter.
```

> El puerto del diálogo de emparejamiento **no** es el puerto de conexión. El de conexión lo entrega `adb mdns services`. Si al emparejar sale error, casi siempre es porque se usó el puerto equivocado.

### 1.2 Conectar

```powershell
& $a mdns services    # _adb-tls-connect._tcp  192.168.1.86:PUERTO   <-- ese es el de conexión
& $a connect 192.168.1.86:38291
& $a devices          # debe decir "device"; "offline" o "no serial number" es que hay que repetir
```

Los puertos cambian cada vez que se reinicia el teléfono o el diálogo: hay que leerlos de nuevo.

### 1.3 El enlace con el servidor (imprescindible)

La app apunta a `127.0.0.1:8000`, así que el puerto del Django viaja por `adb reverse`. **El servidor tiene que estar corriendo en el PC** (`python manage.py runserver`).

```powershell
& $a reverse tcp:8000 tcp:8000
& $a reverse --list   # host-xx tcp:8000 tcp:8000
```

Si se corta la conexión wifi, el `reverse` se pierde: hay que rehacerlo (igual que el `connect`).

#### Camino corto

Los pasos 1.2 y 1.3 están empaquetados en `C:\Users\tokyo-3\dev\conectar.ps1`: busca el dispositivo, lo reconecta por mDNS si hace falta, rehace el `reverse` y comprueba que el servidor responda.

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\tokyo-3\dev\conectar.ps1
```

Devuelve **una sola línea**:

| Salida | Significa |
|---|---|
| `LISTO ...` | Conectado, enlazado y el servidor responde. Se puede lanzar la app |
| `FALTA el telefono no esta conectado` | Abrir *Depuración inalámbrica* en el teléfono y repetir |
| `FALTA no se pudo enlazar el puerto 8000` | adb quedó trabado: `& $a kill-server` y repetir |
| `FALTA el servidor no responde en el 8000` | Falta `python manage.py runserver` en el PC |

Es idempotente: si ya estaba todo hecho, no rompe nada.

### 1.4 Compilar y ejecutar en el teléfono

```powershell
Set-Location 'C:\Users\tokyo-3\Desktop\proyecto\mobile'
& 'C:\Users\tokyo-3\dev\flutter\bin\flutter.bat' run -d adb-R5CWA20CD5X-yPWndS._adb-tls-connect._tcp
```

- Esa consola queda ocupada: ahí viven `r` (hot reload), `R` (hot restart) y `q` (salir). Primera compilación: ~15 s de Gradle + ~35 s de instalación.
- Al terminar imprime la URL de **DevTools** (`http://127.0.0.1:PUERTO/...`): inspector de widgets, logs y perfilador en el navegador del PC.
- Si aparece `Lost connection to device`, normalmente la app pasó a segundo plano: se relanza y listo.

### 1.5 Chuleta

| Quiero | Comando |
|---|---|
| Dejar todo listo de una vez | `powershell -ExecutionPolicy Bypass -File C:\Users\tokyo-3\dev\conectar.ps1` |
| Ver dispositivos | `& $a devices` |
| Puerto de conexión | `& $a mdns services` |
| Reconectar | `& $a connect IP:PUERTO` |
| Rehacer el enlace web | `& $a reverse tcp:8000 tcp:8000` |
| Logs del teléfono | `& $a logcat -d -t 300` |
| Reiniciar adb si se traba | `& $a kill-server` y después `connect` |
| Despertar la pantalla | `& $a shell input keyevent 224` |
| Qué ventana manda | `& $a shell dumpsys window \| Select-String mCurrentFocus` |
| Captura de pantalla | `& $a shell screencap -p /sdcard/x.png` y `& $a pull /sdcard/x.png .` |
| Leer los textos de la pantalla | `& $a shell uiautomator dump /sdcard/ui.xml` y `& $a shell cat /sdcard/ui.xml` |
| Cerrar el panel de notificaciones | `& $a shell cmd statusbar collapse` |

> En el volcado de Flutter los textos están en `content-desc`, **no** en `text` (ese viene vacío). El volcado incluye las cuatro pestañas a la vez, porque viven en un `IndexedStack`.

---

## 2. Ver la pantalla del teléfono en el PC (scrcpy)

Está instalado en `C:\Users\tokyo-3\dev\scrcpy` (v5.0, ZIP comprobado contra el `SHA256SUMS.txt` del release oficial).

```powershell
$env:ADB = 'C:\Users\tokyo-3\dev\android-sdk\platform-tools\adb.exe'
& 'C:\Users\tokyo-3\dev\scrcpy\scrcpy.exe' --stay-awake --no-audio --max-size=1024 --video-bit-rate=4M
```

- `$env:ADB` apunta al adb del SDK para **no** reiniciar el servidor de adb: si lo reinicia, se pierde el emparejamiento wifi.
- `--stay-awake` mantiene la pantalla del teléfono encendida mientras el espejo está conectado. **Úsalo siempre**: con la pantalla apagada Flutter deja de dibujar y cualquier lectura de la interfaz devuelve la última imagen, no la real.
- `--max-size=1024 --video-bit-rate=4M` lo hacen fluido por wifi. Para máxima nitidez: `--max-size=0`.
- Se puede lanzar antes o después de `flutter run`; son independientes.

**Atajos:** el mouse es el dedo, y el clic sostenido es una pulsación larga.

| Tecla | Hace |
|---|---|
| `Alt+f` | pantalla completa |
| `Alt+g` / `Alt+h` | reencuadrar |
| `Ctrl+o` | apaga la pantalla del teléfono, el espejo sigue |
| `Ctrl+q` | cerrar scrcpy |

**Si no abre la ventana:** revisar `& $a devices`. Si el teléfono no aparece, repetir el paso 1.2.

---

## 3. Problemas ya vistos y su causa

| Síntoma | Qué pasó |
|---|---|
| `The ampersand (&) character is not allowed` | El comando empezaba con `&`. Guardar la ruta en una variable |
| `adb pair` da error con el puerto del teléfono | Se usó el puerto de **conexión**; el de emparejamiento solo vive mientras el diálogo está abierto |
| `offline` / `no serial number` | `& $a kill-server` y volver a `connect` |
| `uiautomator` devuelve una pantalla vieja | La pantalla se apagó: usar scrcpy con `--stay-awake`, o `input keyevent 224` |
| Un toque en la barra inferior abre las notificaciones | Es la zona de gestos del sistema: tocar un poco más arriba o cerrar con `cmd statusbar collapse` |
| `flutter analyze` limpio y la app igual se cae en el teléfono | El análisis estático no ve las aserciones de layout. **Probar en el teléfono no es opcional** |
| La consola deja de reconocer cmdlets normales | La sesión se degradó: abrir una terminal nueva |
| El teléfono se bloquea solo en medio de una prueba | Subir el tiempo de apagado de pantalla, o dejar scrcpy con `--stay-awake` |

---

## 4. Automatizar toques (opcional)

`C:\Users\tokyo-3\dev\ui_tmp.ps1` (vive fuera de los repos) trae utilidades: `Dump`, `Centro`, `Tocar <texto>`, `Etiquetas`, `Top`, `Fondo`, `Pestana <x>`, `Despertar`.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
$null = 1; . 'C:\Users\tokyo-3\dev\ui_tmp.ps1'

Pestana 945          # pestaña Tarreo
Tocar 'AGREGAR'      # pulsa el primero que contenga ese texto
```

- El `$null = 1;` delante es necesario: si el comando empieza con `.`, la consola lo rompe.
- `Tocar` busca por el **texto de accesibilidad** (`content-desc`) y pulsa el centro del elemento: no hay que adivinar coordenadas.
- Las pestañas están siempre en `y ≈ 2150` y sus centros en `x`: Inicio 135, Entregas Pendientes 405, Mis Entregas 675, Tarreo 945 (pantalla 1080×2340).
