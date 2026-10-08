# Plan — App móvil Flutter para el Camionero (KIM GAS / GasFácil)

> Análisis previo al desarrollo. Base examinada: `C:\Users\tokyo-3\Desktop\proyecto\gas_project` (Django 5.1.3 + app única `mockups`).
> Fecha: 2026-10-06. Estado: **borrador de diseño, sin código**.
> Repositorio de la app: `https://github.com/infralise123984/gas_facil_movil` (rama `main`, repo separado del de `gas_project` — ver D-16).

## 0. Encuadre decidido por el dueño (2026-10-06)

| Punto | Decisión |
|---|---|
| Relación con la web | La app **es una extensión** del sistema actual. No es un ecosistema aparte y no reemplaza nada |
| Alcance de features | Solo lo que la web **ya hace** para el camionero. **No se inventan features de negocio nuevas** (ej. fotos). La **infraestructura técnica** nueva que haga falta —endpoints, tablas de apoyo, tabla de ubicación— **sí está permitida** |
| **Paridad con la PWA (regla dura)** | **La app debe sentirse como la PWA, no como otra app.** Mismos textos, mismos botones, mismo orden, mismas confirmaciones, mismo flujo. Referencia obligatoria: `entregas/camionero_entregas.html`, `partials/_entregas_cards.html`, `entregas/tarreo.html`, `entregas/historial_camionero*.html` |
| Público | **App interna de la empresa.** Ningún cliente entra al ecosistema; solo camioneros |
| Identidad visual | Se **reutilizan** el nombre y los íconos que ya usa la PWA (`static/img/`). No se diseña branding nuevo |
| Autenticación | Usuario y contraseña, **igual que la web**. Sin login por teléfono. 2FA queda fuera por ahora (es opcional en la web) |
| Backend | Se **reutiliza** el Django existente. Se aceptan endpoints JSON nuevos, pero **sin reescribir lógica**: la API delega en los servicios y modelos que ya usa la web |
| Distribución | **APK firmado por sideload**, servido por el **propio Django** en el mismo dominio. Sin Play Store (empresa pequeña) |
| Evidencia fotográfica | **Descartada** |
| Notificaciones | Se permite agregar la infraestructura necesaria; la elección es latencia vs dependencia (§5) |
| Retención de ubicación | **Máximo 24 horas.** No interesa dónde estaba ayer, solo si está trabajando ahora (§6) |
| Feature futura que motiva la app | **Ver la ubicación de los camiones en tiempo real** (jefe/admin en el panel web). Diseño en §6; no entra en la primera entrega |

---

## 1. Hechos verificados del sistema actual

| Tema | Realidad en `gas_project` (verificado en código) |
|---|---|
| Stack | Django 5.1.3, Python 3.13, MySQL/PostgreSQL/SQLite, Gunicorn + WhiteNoise, Render |
| Arquitectura | **Sin DRF, sin CBV.** Todo FBV con `@login_required`, `@require_POST`, `@never_cache` |
| Endpoints "API" | `entregas/api/` y `entregas/mias/api/` **devuelven HTML renderizado**, no JSON de datos |
| Permisos | `require_roles()` (HTML) y `require_roles_api()` (JSON). Auditoría automática `PERM_DENIED` |
| Auth | Sesión Django + CSRF. Login HTML (`/auth/login/`) → redirect. 2FA TOTP por sesión. django-axes |
| Push | **Web Push + VAPID (`pywebpush`) + Service Worker** → exclusivo de navegador |
| Concurrencia | `select_for_update()` en tomar/entregar/devolver (anti race condition) |
| Anti-duplicado | `form_token` en `request.session` para pedido y tarreo |
| Timezone | `America/Santiago`; helpers `today_chile()`, `now_chile()`, `rango_dia_chile()` |
| Dinero | CLP entero (`DecimalField(decimal_places=0)`). Snapshots de precio en `DetallePedido` |
| Auditoría | `AuditoriaAccion.registrar(...)` + loggers `audit` (INFO) / `security` (WARNING) |
| Restricciones duras | `docs/PLAN_AUDITORIA_OPERATIVA.md` §3: no tocar migraciones, monolito backup, tests existentes, `.env`, `render.yaml`, CSP, auth/2FA/AXES/VAPID/CSRF, ni `notificar_nuevo_pedido` |

---

## 2. Inventario funcional del camionero (alcance real de la app)

| # | Función | Origen actual | Datos que toca |
|---|---|---|---|
| 1 | Ver pendientes disponibles hoy | `camionero_entregas` | `Pedido` estado=pendiente, origen=telefono, entregador=null, fecha hoy |
| 2 | Ver en ruta (sin límite de fecha) | `camionero_entregas` | estado=en_ruta, entregador=user |
| 3 | Ver entregados hoy | `queryset_actividad_camionero_dia` | entregador=user + tarreo/venta_extra propios |
| 4 | Tomar pedido | `camionero_tomar_pedido` | pendiente→en_ruta + `HistorialEstadoPedido` + auditoría |
| 5 | Marcar entregado | `camionero_marcar_entregado` | en_ruta→entregado + historial + auditoría |
| 6 | Cancelar entrega | `camionero_cancelar_entrega` | en_ruta→cancelado, **conserva** entregador |
| 7 | Devolver al pool | `camionero_devolver_pedido` | en_ruta→pendiente, limpia entregador + **re-notifica push** |
| 8 | Venta tarreo | `tarreo_pedido` | crea `Pedido` origen=tarreo estado=entregado, entregado inmediato |
| 9 | Venta adicional en entrega (`venta_extra`) | `editar_pedido` (camionero, en_ruta) | agrega detalles a pedido en ruta |
| 10 | Historial diario/mensual | `camionero_historial`, `camionero_historial_dia` | kilos, montos, entregas, desglose domicilio/tarreo |
| 11 | Notificación de pedido nuevo | Web Push VAPID | `PushSubscription` |
| 12 | Perfil / cambio de clave / 2FA | `perfil_view`, `activar/desactivar_2fa` | `Usuario` |

**Fuera del alcance del camionero hoy:** sobres diarios (`views/sobres.py` exige `bodeguero|jefe|admin`), reportes, balones, sectores, consultas, administración.

> Observación de negocio: el **sobre tipo `camion`** (rendición de caja del camionero, con kilometraje, pagos y gastos) lo abre/cierra el bodeguero o jefe, **no el camionero**. Queda **fuera de la app**: la web ya lo resuelve con otro rol, y agregarlo sería una feature nueva para el camionero (§10, D-5).

> **Asignación implícita por zona:** en la web el pool es compartido (`entregador__isnull=True`, cualquiera toma), pero en la práctica cada camionero toma lo suyo por zona y calle. Ese reparto **no está en el modelo** (existen `Pedido.sector` y `Sector.zona`, pero no una asignación por camionero). La app **no debe inventar** asignación automática: el repo lo prohíbe expresamente (`PLAN_AUDITORIA_OPERATIVA.md` §3.2, "no agregar automatismos que cambien estados de pedidos") y además sería una feature nueva. Lo que **sí** corresponde es **mostrar `sector` y `direccion_entrega` en grande y agrupar/ordenar la lista por sector**, que es solo presentación de datos que ya existen.

> **Paridad con la PWA (regla dura):** la app replica la interfaz y el flujo de las páginas del camionero. **No se agregan pantallas, botones, campos ni funciones que la web no tenga.** Si algo no existe en la web, no va en la app.

### 2.1 Contrato de navegación y pantallas (verificado en los templates)

**Barra inferior del camionero** — `base.html`, solo para `user.rol == "camionero"`, alto 68 px:

| # | Etiqueta | Ícono | Destino |
|---|---|---|---|
| 1 | Inicio | `house-door-fill` | `index` |
| 2 | Entregas Pendientes | `truck` | `entregas_lista` |
| 3 | Mis Entregas | `check-circle-fill` | `entregas_mias` |
| 4 | **Tarreo** — destacado en verde, texto blanco, en negrita | `bag-plus-fill` | `entregas_tarreo` |

→ Esa barra es **la referencia directa** de la navegación de la app: mismos 4 ítems y la misma jerarquía visual. El **historial no está en la barra inferior**; se llega desde "Mis Entregas" ("Ver historial por mes") o desde la barra superior.

**Barra superior:** Entregas · Mis Entregas · Historial, y el menú de usuario con **Mi perfil** y **Cerrar sesión** (POST). En la app se traduce a un ícono de perfil en el AppBar con esas dos opciones. No se agregan ítems.

| Pantalla | Template de referencia | Contenido a replicar |
|---|---|---|
| Inicio | `index.html` | Logo, reloj **del servidor**, y tres tarjetas: Entregas Pendientes / Mis Entregas Hoy / Historial de Ventas |
| Entregas | `entregas/camionero_entregas.html` + `partials/_entregas_cards.html` | Contador "N pendientes • M en ruta". **En Ruta**: MARCAR ENTREGADO, CANCELAR ENTREGA, Editar Pedido, DEVOLVER PEDIDO. **Pendientes**: TOMAR PEDIDO. Vacío: "Todo listo / No hay entregas pendientes ni en ruta por ahora." |
| Mis Entregas | `entregas/mis_entregas_camionero.html` + `partials/_mis_entregas_camionero_cards.html` | Badges: entregas de hoy, monto en CLP, kg vendidos. Tarjeta por pedido con borde según estado (success/warning/danger/info), lista de productos con subtotal, total, dirección + sector, fecha y hora. Los **cancelados** van en rojo con "NO COBRADO" y el monto tachado |
| Tarreo | `entregas/tarreo.html` | Cantidades por balón del catálogo activo, método de pago, dirección opcional (por defecto "Tarreo / venta directa en camión"). **Sin descuentos** |
| Historial | `entregas/historial_camionero.html` y `..._dia.html` | Grilla mensual con kilos por día, navegación de mes, detalle del día |
| Editar pedido | `pedidos/editar_pedido.html` | Cabecera (método de pago, sector, dirección) + líneas (balón, cantidad). `puede_descontar` es **False** para el camionero |
| Perfil | `auth/perfil.html` | Datos personales, cambio de contraseña, 2FA |

**Lo que la PWA NO ofrece al camionero** (y por lo tanto la app tampoco): teléfono del cliente (no existe en el modelo), mapa/GPS, fotos, códigos de barras, firmas de cliente, reportes de negocio, ni ninguna pantalla de administración.

**Única excepción deliberada:** el botón "Activar Notificaciones" de la PWA **no se replica**, porque en la app las notificaciones son del sistema operativo (§5). Es el único elemento de la web que desaparece, y por una razón técnica, no de producto.

---

## 3. Brechas para una app nativa

| Brecha | Impacto |
|---|---|
| No existe API de datos (los "api/" devuelven HTML) | **Bloqueante.** Sin endpoints JSON no hay app |
| No hay autenticación para clientes nativos (solo sesión+CSRF, respuestas HTML) | **Bloqueante.** Falta login JSON + 2FA JSON |
| Web Push no existe en Flutter nativo (requiere Service Worker) | Se resuelve aparte: polling en background o FCM (§5) |
| Race conditions resueltas en el servidor; una app con reintentos puede duplicar acciones | Alto (dinero / estados) |
| Sin `Idempotency-Key` | Alto: reintento offline puede marcar entregado 2 veces o duplicar tarreo |
| CORS/CSP `connect-src 'self'` | Solo afecta a clientes web; el nativo no aplica CORS. No requiere debilitar CSP |
| Sin trazabilidad de dispositivo (ni token de dispositivo, ni versión de app, ni crash logs) | Medio: el plan de auditoría operativa pide evidencia de cliente |
| Sin ubicación en el sistema | El modelo no guarda posición. Requiere una tabla nueva, pero es la feature que motiva la app (§6, §10 D-6) |

---

## 4. Backend: opciones (pedido: pros y contras)

### Opción A — API JSON dentro del Django actual, sin DRF *(recomendada)*
Nuevo paquete `mockups/api/` con FBV JSON. Reutiliza `require_roles_api`, servicios (`services/camionero.py`), auditoría e `Idempotency-Key` propio.

- **Pros:** una sola app y un solo deploy; cero duplicación de lógica de negocio; `select_for_update()` ya probado; auditoría e historial intactos; migraciones compartidas; respeta la restricción de no tocar auth (endpoints aditivos).
- **Contras:** toca el repo en producción (mitigable: prefijo `/api/v1/`, feature flag, tests nuevos, sin modificar vistas existentes); serialización manual sin serializers; hay que reimplementar validación de entrada en JSON.

### Opción B — DRF en el mismo repo
Nueva app `api/` con `djangorestframework` (+ `simplejwt` opcional).

- **Pros:** serializers, paginación, throttling, permisos, OpenAPI automático, testing con APIClient.
- **Contras:** nueva dependencia en producción; los permisos genéricos de DRF **no** conocen `require_roles` → hay que reimplementar autorización a nivel de objeto (riesgo **IDOR/BOLA** si se olvida); convivencia de dos estilos de vista; más superficie de cambio.

### Opción C — Backend separado contra la misma BD
- **Pros:** aísla el riesgo del repo de producción.
- **Contras:** **duplica lógica crítica** (cancelar/devolver/tarreo/cálculo de totales/sync de sobres); sus escrituras **saltan** `AuditoriaAccion`, `HistorialEstadoPedido` y `HistorialCambioPedido` → se rompe la trazabilidad y el plan de auditoría operativa; acoplamiento a esquema; doble deploy. **No recomendada.**

**Decidido: Opción A.** Es la única que cumple "reusar lo más posible" sin duplicar lógica ni perder la auditoría. La Opción C queda descartada por romper la trazabilidad; la B se reserva para más adelante y solo si la API crece, con permisos explícitos que deleguen en `require_roles` (nunca `ModelViewSet` por defecto).

**Regla de oro:** el endpoint nuevo es transporte + validación de entrada. El cambio de estado lo ejecuta el **mismo** servicio o la **misma** secuencia (`select_for_update` + `HistorialEstadoPedido` + `AuditoriaAccion`) que usa la web. Cero lógica de negocio duplicada.

**Reutilización concreta (verificado en código):**

| Necesidad | Se reutiliza |
|---|---|
| Listado y estadísticas | `services/camionero.py` (`queryset_actividad_camionero_dia`, `stats_ventas_camionero`, `stats_dia_camionero`) |
| Catálogo y precios | `services/catalogos.get_balones_activos_ordenados()` |
| Anulación | `services/pedidos.anular_pedido` + `AnulacionNoPermitida` |
| Sobres afectados | `services/sobres` (`hay_sobre_cerrado_para_pedido`, `resincronizar_sobres_afectados_por_pedido`) |
| Permisos y auditoría | `utils/permisos.require_roles_api`, `AuditoriaAccion.registrar`, loggers `audit` / `security` |
| Fechas | `utils/fechas` (`today_chile`, `now_chile`, `rango_dia_chile`) |

### Contrato de API propuesto (fase 1)

> **Especificación completa y definitiva:** `gas_project/docs/API_MOVIL.md`. Ese archivo es el contrato de referencia para implementar la API en el repo web; acá queda solo el resumen.

```
POST /api/v1/auth/login/            {username, password} → 200 {usuario, rol} | 202 {requiere_2fa}
POST /api/v1/auth/2fa/              {codigo} → 200 {usuario}
POST /api/v1/auth/logout/
GET  /api/v1/auth/perfil/           → {id, nombre, rol}

GET  /api/v1/entregas/              → {pendientes, en_ruta, entregados_hoy, actualizado_en, version}
POST /api/v1/entregas/{id}/tomar/
POST /api/v1/entregas/{id}/entregar/
POST /api/v1/entregas/{id}/cancelar/
POST /api/v1/entregas/{id}/devolver/

POST /api/v1/tarreo/                {balones:[{id,cantidad}], metodo_pago, direccion}
GET  /api/v1/balones/               → catálogo con precios vigentes
GET  /api/v1/historial/?desde=&hasta=
GET  /api/v1/historial/{fecha}/

GET  /api/v1/version/               → {version_minima, url_apk}   (aviso de actualización: sideload no se auto-actualiza)
GET  /apk/gasfacil-camionero.apk    → el APK, servido por el propio Django (mismo dominio, sin repositorio externo)

# Solo si el piloto justifica FCM (D-3) o se activa la feature de ubicación (§6):
# POST /api/v1/dispositivos/        {fcm_token, plataforma, app_version}
# POST /api/v1/ubicacion/           {muestras:[{lat, lng, precision_m, capturado_el, ...}]}
```

Todo mutador: header `Idempotency-Key: <uuid>` obligatorio, respuesta idéntica en reintento.
Todo error: `{error: {codigo, mensaje}}` sin stack traces ni detalles internos (OWASP).

**Dónde se guarda el APK:** Render usa un sistema de archivos **efímero**; todo lo que se genere durante el build desaparece en el siguiente deploy. El APK debe venir **versionado dentro del repositorio** (o en un disco persistente) y servirse por una vista propia, no desde una carpeta creada por `collectstatic`.

**2FA:** los camioneros no lo usan por ahora. Los endpoints de login deben, igual, **responder de forma explícita** si una cuenta lo tiene activo (caso `requiere_2fa`), para no dejar al usuario en un error confuso.

### Reglas transversales del contrato (aplican a todos los endpoints)

| Regla | Detalle |
|---|---|
| **Sobre de respuesta** | Toda respuesta incluye `servidor_ahora` (ISO, `America/Santiago`). Resuelve el reloj del Inicio (§2.1), ordena la cola offline y evita depender del reloj del teléfono |
| **Fechas** | La app **nunca** calcula "hoy". El servidor entrega el día y los rangos, con `today_chile()` / `rango_dia_chile()` |
| **Dinero** | El servidor es la única fuente de verdad y siempre recalcula con `calcular_totales()`. La app solo formatea |
| **Números** | Formato `es-CL` (CLP con separador de miles) en el cliente; el servidor entrega enteros sin formato |
| **Errores** | `{error: {codigo, mensaje}}`, con `codigo` estable (`no_disponible`, `sin_permiso`, `bloqueado`, `conflicto_estado`) para que la app decida sin depender de texto libre |
| **Reintentos** | Backoff exponencial con tope y máximo N intentos. **Nunca** descartar un ítem de la cola en silencio: o sincroniza, o queda marcado como conflicto visible |
| **Compatibilidad** | `/api/v1/` queda **congelada** mientras la PWA siga en uso: no se rompe el contrato, se agrega versión nueva si hiciera falta |
| **Rollback del piloto** | La PWA queda intacta. Si la app falla, el camionero vuelve al navegador sin migrar nada |

---

## 5. Notificaciones al camionero

Aclaración del dueño (2026-10-06): la restricción es **no inventar features de negocio** (nada de fotos ni de funciones que la web no tenga). La **infraestructura técnica** nueva sí está permitida, así que FCM queda desbloqueado.

**Web Push (VAPID) no se puede reutilizar en una app nativa:** el endpoint de push pertenece al navegador, no al dispositivo; `pywebpush` no puede entregar a Flutter; y un `WebView` no conserva el Service Worker con la app cerrada. La PWA sigue con Web Push intacto.

| Opción | Avisa con la app cerrada | Infra nueva | Latencia | Esfuerzo |
|---|---|---|---|---|
| **`WorkManager` (15 min) + notificación local** | Sí | Ninguna | hasta 15 min | Bajo |
| Refresco al abrir / volver a primer plano + botón manual | Solo con la app abierta | Ninguna | inmediata | Bajo |
| **FCM (`firebase_messaging`)** | Sí, inmediato | 1 tabla `DispositivoPush` + proyecto Firebase + `notificar_nuevo_pedido_movil()` | inmediata | Medio |
| WebSocket (Django Channels, ASGI) | No | Gunicorn WSGI → ASGI | inmediata | Alto |
| Foreground service + WebSocket | Sí, con notificación permanente | ASGI + batería | inmediata | Alto |

**Realidad del negocio (dato del dueño, 2026-10-06):** son **2 camioneros** y **no compiten por pedidos**: cada uno reconoce los suyos por zona y calle. El pool compartido es una *implementación* del sistema, no una competencia real.

Consecuencia: **la latencia no cuesta ventas.** Un pedido espera al camionero que le corresponde.

**Elegido: `WorkManager` cada 15 min + notificación local.** Cero dependencias, cero terceros, cero infraestructura nueva.

**FCM queda como *opt-in*** solo si el piloto demuestra que 15 min hacen perder el pedido (p. ej. el camionero ya pasó la calle y no vuelve hasta el otro día). Es una decisión reversible: si se cambia después, agrega una tabla aislada y no toca nada de lo ya hecho.

**Común a ambas rutas**
- Refresco inmediato al abrir la app o volver a primer plano, más botón "refrescar" manual.
- Pausar el trabajo en background fuera de jornada (o sin pedidos asignados) para no gastar batería ni datos.
- Desde Android 13 la notificación local exige el permiso `POST_NOTIFICATIONS`: pedirlo al iniciar sesión con explicación clara.
- **No se modifica `notificar_nuevo_pedido` ni se retira Web Push.** Con FCM se agrega `notificar_nuevo_pedido_movil()` en módulo aparte, llamada junto a la existente en los 2 puntos actuales (`views/pedidos.py` al crear, `views/entregas.py` al devolver).

---

## 6. Seguimiento de ubicación del camión (feature futura que motiva la app)

Objetivo: el jefe ve en tiempo real dónde están los camiones.

**Reparto de responsabilidades**
- **App móvil:** único productor de la posición (GPS del teléfono del camionero).
- **Panel web (jefe/admin):** único consumidor, sobre el mapa.
- **Backend:** almacén de posiciones + endpoint de lectura.

**Para qué se usa (definido por el dueño, 2026-10-06)**
Saber **en tiempo real** si el camionero está trabajando o si lleva una hora detenido sin hacer nada. **No interesa saber dónde estaba ayer.**

**Retención: máximo 24 horas**
- La tabla guarda una **ventana móvil de 24 h**; no hay histórico acumulativo.
- Se poda **en el propio endpoint de ingesta**: en cada `POST` se borran las muestras de ese trabajador con más de 24 h. Es barato, acotado y **no requiere cron** (el repo prohíbe automatismos temporales; esta purga no toca pedidos, pero mejor evitarla igual).
- Comando de gestión opcional (`purgar_ubicaciones`) como red de seguridad manual, **no** como tarea programada.
- El límite se lee de una variable de entorno con 24 h por defecto, para poder bajarlo sin tocar código.

**Diseño propuesto (mínimo y aislado)**
1. Una tabla nueva, sin tocar las existentes:
   `UbicacionCamion(id, trabajador FK Usuario, lat, lng, precision_m, velocidad?, bateria?, capturado_el, recibido_el)` con índice en `(trabajador, capturado_el)`.
2. `POST /api/v1/ubicacion/` acepta un **lote** de muestras, con la misma cola offline y `Idempotency-Key` del resto de la app, y poda lo que exceda las 24 h.
3. `GET /api/v1/ubicacion/estado/` → por camionero: última posición, hora de la última muestra y el **indicador de actividad** calculado en el servidor.
4. Vista web nueva, visible solo para `jefe`/`admin`, con el mapa y el indicador.

**Indicador "trabajando / detenido" (lo que el jefe quiere ver)**
Se calcula comparando la muestra más reciente con la de hace ~60 min. Es un cálculo derivado, no un estado nuevo:

| Estado | Regla | Interpretación |
|---|---|---|
| **En movimiento** | se desplazó más de ~150 m en los últimos 10 min | Está en ruta |
| **Detenido hace X** | desplazamiento < ~150 m desde hace X minutos, con X ≥ 60 | Puede estar entregando, o inactivo |
| **Sin reportar hace X** | no llegan muestras desde hace X minutos | App cerrada, sin batería, sin señal o fuera de jornada |
| **Fuera de jornada** | no corresponde reportar | — |

No toca `Pedido`, no genera sanciones y no notifica al camionero. El jefe mira y decide.

**Desambiguar "detenido" de "trabajando"**
Un camionero detenido puede estar trabajando (descargando). Por eso el panel debe mostrar, junto al indicador, el contexto que **ya existe** en el sistema:
- pedidos `en_ruta` y hora del último cambio de estado,
- entregas completadas hoy,
- hora de la última muestra.

Detenido hace 1 h **con pedidos `en_ruta` sin movimiento** = lo que el jefe quiere detectar. Detenido hace 1 h sin pedidos pendientes = está al día.

Regla explícita: **sin alertas automáticas ni notificaciones por inactividad.** Sería una feature nueva y un riesgo laboral añadido.

**Frecuencia y batería (se decide en el cliente, no en el servidor)**
- Reportar cada 30–60 s **solo** con jornada activa; suspendido cuando no hay entregas.
- Para poder afirmar "lleva una hora detenido" hacen falta muestras cada pocos minutos: con 1 muestra/min, la ventana de 24 h son ~1 440 filas por camionero (trivial para la base).
- `foregroundServiceType="location"` (Android 14+ exige declarar el tipo) con notificación persistente "Compartiendo ubicación".
- Pedir **exención de optimización de batería**. Varios fabricantes (Xiaomi, Samsung, Huawei) matan servicios en background aunque haya notificación persistente; sin la exención el reporte se corta solo y el jefe vería "sin reportar" sin causa real.
- Buffer local + envío por lotes al recuperar red: no se pierde el trayecto en zonas sin señal.

**No hay que debilitar el CSP.** `mockups/middleware.py` ya permite `script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net` y `img-src 'self' data: https:`, suficiente para Leaflet desde CDN con teselas por HTTPS. Alternativa sin CDN: empaquetar Leaflet en `static/`.

**Estado legal: en investigación por el dueño junto con la jefa (2026-10-06).** No es un problema técnico y **no se implementa hasta que exista acuerdo**. Lo que sigue es un punto de partida para esa conversación, **no una conclusión jurídica**.

**Normas a revisar (Chile)**
- **Ley 19.628** sobre protección de la vida privada (vigente).
- **Ley 21.719** (publicada en diciembre de 2024): reemplaza el régimen anterior y crea la Agencia de Protección de Datos Personales. Su entrada en vigencia es **diciembre de 2026**, es decir, en semanas. Agrega base de licitud explícita, deber reforzado de información, derechos de acceso/rectificación/supresión/oposición y evaluación de impacto en tratamientos de riesgo.
- **Código del Trabajo, art. 5**: las facultades del empleador se ejercen respetando las garantías del trabajador.
- **Pronunciamientos de la Dirección del Trabajo** sobre geolocalización de vehículos de la empresa: el criterio reiterado es que el control es admisible con conocimiento del trabajador, dentro de la jornada y limitado al bien de la empresa, no a la persona.

**Preguntas concretas para la jefa**
1. ¿El teléfono es **de la empresa** o del camionero? (D-14) Un equipo entregado por la empresa con uso acordado tiene una posición muy distinta a rastrear un teléfono personal.
2. ¿El control se usará solo para **operación** (coordinar entregas) o también para **sanciones**? El uso sancionatorio tiene más requisitos.
3. ¿Se controla el **vehículo** o el **trabajador**, y solo en jornada?
4. Ya se decidió guardar **máximo 24 h** (§6). ¿Le parece suficiente a la jefa, o preferiría guardar solo la última posición?
5. ¿El control está declarado en el **contrato o reglamento interno**?
6. ¿El camionero puede **ver sus propios datos**?

**Medidas que reducen el riesgo (aplicables por diseño, si se aprueba)**
- **Minimizar**: reportar **solo mientras hay un pedido `en_ruta`**. Es la posición de una tarea, no de la persona.
- **Ventana de 24 h** (ya decidido, ver arriba): no existe historial acumulativo ni posibilidad de reconstruir dónde estaba la semana pasada. Es el argumento de minimización más fuerte de todo el diseño.
- **Visibilidad**: notificación permanente "Compartiendo ubicación" mientras se reporta, para que el camionero siempre sepa cuándo está activo.
- **Ámbito**: solo jornada; apagado fuera de horario y en vacaciones. **Falta definir qué es "jornada"** (D-15).
- **Acceso restringido**: solo `jefe`/`admin`, y cada consulta registrada en `AuditoriaAccion`.

Lo que se decida en contra de estas medidas debe quedar escrito en este documento antes de programar.

**Estado:** no se implementa en la primera entrega. Se diseña ahora porque condiciona tres decisiones de la app:
- el permiso de ubicación en background (conviene pedirlo junto al resto de permisos),
- la app debe poder ejecutar trabajo en background (afecta la arquitectura completa, no solo esta feature),
- el volumen de llamadas al backend crece: medirlo temprano.

**MVP del MVP, si se aprueba:** reportar solo mientras hay un pedido `en_ruta`, y mostrar en el panel web únicamente la "última posición conocida", sin histórico.

---

## 7. Arquitectura Flutter propuesta

```
lib/
├── main.dart
├── app/                    # MaterialApp, go_router, tema (alto contraste, botones ≥56dp)
├── core/
│   ├── config/             # baseUrl vía --dart-define, versión mínima soportada
│   ├── network/            # Dio + interceptores (auth, Idempotency-Key, retry, logging)
│   ├── storage/            # flutter_secure_storage (sesión), Drift (datos)
│   ├── error/              # excepciones de dominio + mapeo a mensajes para el usuario
│   └── sync/               # SyncEngine, OutboxQueue, ConnectivityWatcher
├── features/
│   ├── auth/               # login, 2FA, sesión
│   ├── entregas/           # domain / data / application / presentation
│   ├── tarreo/
│   ├── historial/
│   └── notificaciones/
└── shared/                 # widgets reutilizables (botón grande, tarjeta de pedido)
```

- **Estado:** Riverpod. **Ruteo:** go_router. **Red:** dio. **BD local:** Drift (SQLite tipado, migraciones versionadas). **Conectividad:** connectivity_plus. **Background:** `workmanager` + `flutter_local_notifications` (FCM solo si el piloto lo justifica, D-3). **Errores:** Sentry o Crashlytics (si D-12 se aprueba).
- **Capas:** presentation → application (casos de uso) → domain (entidades + interfaces de repositorio) → data (fuentes remotas y locales + implementación de repositorio). La UI nunca llama a Dio.
- **UI accesible:** botones grandes, confirmación explícita en acciones destructivas (cancelar), montos en CLP con separador de miles, tipografía grande, sin dependencia de gestos finos.
- **Android:** `minSdk 26` (Android 8) como valor por defecto. Los teléfonos son modernos y la PWA ya funciona en ellos; se ajusta en el build si hiciera falta, sin impacto en la arquitectura.
- **UI = la PWA (§2):** los widgets imitan `partials/_entregas_cards.html` (contador arriba, secciones "En Ruta" y "Pendientes", una tarjeta grande por pedido, botones a ancho completo con los mismos textos) y el modal de confirmación de la web se replica como diálogo nativo.
- **Navegación = la barra inferior de `base.html` (§2.1):** 4 destinos (Inicio, Entregas Pendientes, Mis Entregas, Tarreo) más el ícono de perfil. La app **no inventa** una estructura de menú propia.

---

## 8. Offline-first y sincronización (patrón outbox)

**Regla:** toda mutación se escribe primero local y se encola. El servidor es la única fuente de verdad del dinero y del estado.

1. Cada acción del camionero genera un registro local con `client_uuid` (UUID v7), `payload`, `estado` (`pendiente|enviado|confirmado|conflicto|rechazado`), `intentos`, `creado_el`.
2. `SyncEngine` drena la cola: al recuperar conectividad, al abrir la app, y periódicamente. Envía `Idempotency-Key = client_uuid`.
3. Servidor: tabla `OperacionIdempotente (clave, usuario, respuesta_json, creado_el)` con índice único en `clave`. Si la clave existe → devuelve la respuesta guardada sin re-ejecutar. **Sin esto, un reintento offline marca dos entregas o duplica una venta tarreo.**

   > Esta tabla es **infraestructura técnica**, no una feature de negocio: no aparece en ningún flujo del negocio ni en la web, y el encuadre de §0 la permite expresamente. Alternativa más liviana si se prefiere no agregar tabla: columna `client_uuid` en `Pedido` + reutilizar `HistorialEstadoPedido` para la trazabilidad. Ambas exigen una migración; la tabla aparte es más simple de auditar y de purgar.
4. Lista de lecturas: se cachea `entregas/` con `version`/`actualizado_en` del servidor; si coincide, no se re-descarga.
5. Conflictos:
   - **Tomar:** el servidor gana. Si ya no está disponible → `409`; la app limpia el pedido de la lista y avisa.
   - **Entregar/cancelar/devolver:** idempotente por `Idempotency-Key`. Si el estado cambió por otro actor, `409` con motivo → el ítem pasa a `conflicto` y se muestra al camionero (no se descarta en silencio).
   - **Tarreo:** si el `client_uuid` ya existe → no se duplica.
6. Los precios y el catálogo de balones se cachean con su fecha; al reenviar tarreo se envía `precios_version` para que el servidor detecte un cambio y recalcule (el servidor siempre recalcula con `calcular_totales()`).
7. Indicador de sincronización visible y permanente (pendientes por subir / todo sincronizado / sin señal).

---

## 9. Seguridad (OWASP aplicado al móvil)

| Riesgo | Mitigación |
|---|---|
| Tokens/cookies en claro | `flutter_secure_storage` (Keystore). Nunca en `SharedPreferences` ni en logs |
| **IDOR/BOLA** en los nuevos endpoints | Cada acción valida `entregador == request.user` y estado válido, igual que hoy. Tests dedicados por endpoint |
| Escalada de privilegios vía descuentos | **Verificado en `forms.py`**: `DetallePedidoForm._configurar_campo_descuento()` **elimina el campo** si el rol no está en `ROLES_CON_DESCUENTO` (`telefonista`, `jefe`, `admin`), así que un POST con `descuento_unitario` de un camionero se ignora. El endpoint JSON debe replicar exactamente esa regla con `puede_otorgar_descuento()` |
| Bloqueo cruzado por IP (`django-axes`) | **Verificado**: `AXES_LOCKOUT_PARAMETERS` no está configurado y el valor por defecto de `axes 7.0.1` es `["ip_address"]` → 5 intentos fallidos bloquean **toda esa IP** por 1 h. En móvil la IP es de la operadora (CGNAT, IP compartida). La app debe: no reintentar tras un bloqueo, mostrarlo con claridad y no gastar intentos (contraseña visible + teclado adecuado) |
| Duplicación de acciones (dinero) | `Idempotency-Key` + transacción atómica + `select_for_update` |
| Fuerza bruta en login | Reutilizar el login de Django para no perder `django-axes`; throttling adicional en el endpoint |
| Fuga de errores internos | Respuestas de error genéricas; detalle solo en logs del servidor |
| Tráfico en claro | HTTPS obligatorio, `usesCleartextTraffic=false`. Pinning de certificado opcional (rompe si rotan el certificado) |
| Secretos en el repo | `baseUrl` y entorno vía `--dart-define`; **`keystore.jks` y sus contraseñas fuera del repo** (si se pierde, la app instalada no se puede actualizar nunca más) |
| APK de origen controlado | Distribución interna por enlace directo + `GET /api/v1/version/` que avisa cuando hay versión nueva |
| Replay de payloads | `Idempotency-Key` de un solo uso + expiración (p. ej. 7 días) |
| Acceso físico al teléfono | Cierre de sesión por inactividad, PIN/biometría opcional, bloqueo de capturas en pantallas con dinero (opcional) |
| Datos en el dispositivo | SQLite en sandbox de la app; opción SQLCipher si se exige cifrado en reposo |

---

## 10. Decisiones

### Cerradas

| ID | Decisión | Efecto |
|---|---|---|
| D-1 | **APK firmado por sideload**, sin Play Store | Actualizaciones manuales; el backend expone versión mínima (`GET /api/v1/version/`, contrato en §4) |
| D-2 | La app **no reemplaza nada**; la PWA del camionero sigue disponible | Convivencia indefinida; no se retira código web |
| D-3 | **`WorkManager` 15 min + notificación local**; FCM solo como *opt-in* si el piloto lo justifica | Con 2 camioneros que no compiten por el pool, la latencia no cuesta ventas (§5) |
| D-4 | **Reusar el login/2FA actual** con endpoints JSON aditivos | No se toca `auth.py`; cero dependencias nuevas; `django-axes` sigue protegiendo el login |
| D-5 | El camionero **no** hace su sobre/rendición desde la app | La web ya lo resuelve con bodeguero/jefe; agregarlo a la app sería una feature nueva para el camionero, fuera del encuadre de §0 |
| D-7 | **Sin evidencia fotográfica** | Nada que almacenar ni subir |
| D-8 | **Un teléfono por camionero** | Sesión y caché propias de cada uno; sin mezcla de datos ni logout compartido. Permite sesión de larga duración |
| D-9 | Se incluye `venta_extra` (agregar productos a un pedido en ruta) | La función ya existe en la web: se expone, no se inventa |
| D-10 | La app **reutiliza** los servicios Django; nada de lógica duplicada | El endpoint es transporte + validación |
| D-16 | **Repo separado** para la app Flutter; los cambios de API van en el repo de `gas_project` | Dos repos y dos deploys: cada cambio de API se despliega por separado, y `mobile/` se versiona como proyecto propio |

### Abiertas

| ID | Decisión | Por qué importa |
|---|---|---|
| D-6 | **En investigación (dueño + jefa): base legal del seguimiento GPS** | La Ley 21.719 entra en vigencia en diciembre de 2026; sin acuerdo no se programa. La ventana de 24 h (§6) juega a favor |
| D-15 | **Qué se considera "jornada"** para reportar ubicación | Es el límite que hace legal el control: botón explícito de inicio/término, o regla implícita ligada a la actividad del día (§6)
| D-11 | Custodia y respaldo de la **clave de firma del APK** (`keystore.jks`) | Si se pierde, la app instalada no se puede actualizar nunca más |
| D-12 | ¿Telemetría de fallos (Sentry/Crashlytics) o nada? | Sin ella, un error en ruta se diagnostica a ciegas; agrega un tercero |
| D-13 | Cómo se avisa al camionero de una versión nueva | El sideload no se auto-actualiza |
| D-14 | ¿El teléfono es **de la empresa** o del camionero? | Cambia la posición legal del seguimiento y define soporte: quién paga los datos, qué pasa si se pierde o se rompe |

---

## 11. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Romper producción al agregar la API | Prefijo `/api/v1/`, endpoints nuevos, feature flag, tests nuevos en archivo aparte (no tocar tests existentes), deploy en Render con rollback |
| Doble acción por reintento offline | `Idempotency-Key` + tests de reintento |
| Divergencia de lógica entre web y móvil | La API reutiliza los mismos servicios (`services/camionero.py`, `services/pedidos.py`) |
| Notificaciones duplicadas (Web Push + FCM) | El despachador excluye por canal; el móvil no registra Web Push |
| Camioneros con celulares antiguos | La PWA sigue disponible (convivencia decidida); no se retira |
| Rotación de personal y capacitación | Manual de instalación + pantalla de ayuda con botones grandes |
| Rota el esquema de la API | Versionado en la URL + header `X-App-Version` para exigir actualización mínima |
| Cobertura de tests baja en el cliente | Tests de casos de uso + `SyncEngine` con dobles de prueba; widget tests del flujo crítico |
| **Sistema de archivos efímero en Render** | El APK se pierde en cada deploy si se genera durante el build. Debe venir versionado en el repositorio (o en un disco persistente) y servirse por una vista propia, nunca desde `collectstatic` |
| **Bloqueo de login por IP compartida** | Verificado en `axes 7.0.1`: sin `AXES_LOCKOUT_PARAMETERS` configurado, el bloqueo es **por IP** (5 intentos, 1 h). En móvil la IP es de la operadora. Riesgo heredado de la web; la app lo mitiga no reintentando y mostrando el bloqueo |
| **Seguimiento GPS y relación laboral** | Investigación en curso con la jefa (D-6). A favor: ventana de 24 h, reporte solo durante la tarea y visibilidad para el camionero (§6). Sin acuerdo no se programa |
| **Confundir "sin reportar" con "no está trabajando"** | El estado puede deberse a batería, señal o app cerrada. El panel debe distinguirlo y nunca tratarlo como falta. Es un dato para conversar, no para sancionar (§6) |
| **Batería y datos por polling + GPS** | Frecuencia adaptativa; trabajo en background solo con jornada activa; medir consumo en el piloto |
| **Pérdida o robo del teléfono con sesión activa** | Cierre de sesión por inactividad, expiración de sesión, posibilidad de desactivar el usuario desde la web (ya existe) |
| **Un camionero toma el pedido del otro** | Es esperable sin asignación por zona: `devolver al pool` debe estar a un toque y bien visible, y `sector` / `direccion_entrega` siempre a la vista |

---

## 12. Roadmap por fases

| Fase | Entregable | Criterio de cierre |
|---|---|---|
| **F0** | Contrato de API definitivo (validado contra `gasmanager/urls.py`) + spike de login desde Flutter | Login del camionero funcionando contra el servidor |
| **F1** | Esqueleto Flutter (capas, Riverpod, Dio, router) + login (usuario y contraseña; sin 2FA) + lista de entregas (solo lectura) con la misma interfaz de la PWA | El camionero ve pendientes / en ruta / entregados igual que en el navegador |
| **F2** | Acciones: tomar, entregar, cancelar, devolver + `Idempotency-Key` en el servidor | Replican reglas, historial y auditoría de la web |
| **F3** | Offline-first: Drift + outbox + `SyncEngine` + indicador de sync | Marcar entregado sin señal y sincronizar después sin duplicar |
| **F4** | Tarreo + `venta_extra` + catálogo y precios | Venta registrada con montos validados por el servidor |
| **F5** | Notificaciones: `WorkManager` (15 min) + notificación local + refresco al volver a primer plano | El camionero se entera del pedido con la app cerrada |
| **F6** | Historial diario/mensual + estadísticas | Paridad con `camionero_historial` |
| **F7** | APK firmado, servido por Django (`GET /apk/...`) + `GET /api/v1/version/` + manual de instalación | Un camionero instalado y operando desde el APK |
| **F8** | Piloto real + telemetría (si D-12 se aprueba) | Una semana en ruta sin incidentes de dinero |
| **F9** | *(solo si D-6 se aprueba)* Envío de ubicación (ventana 24 h) + mapa e indicador trabajando/detenido en el panel del jefe | El jefe ve la posición de cada camión y distingue "detenido hace 1 h con pedidos en ruta" de "al día" |

**Estimación gruesa:** F0–F4 ≈ 60 % del esfuerzo. F3 (offline) es el mayor riesgo técnico; F9 depende de una decisión legal, no técnica.

---

## 13. Próximo paso

1. **Instalar el toolchain de desarrollo (§17).** Sin esto no hay F1.
2. Investigar el punto legal (**D-6**) con la jefa, usando el checklist de §6.
3. Definir **D-15** (qué es "jornada") y **D-14** (teléfono de empresa o personal) antes de comprar equipos.
4. Decidir **D-17** (versionado del APK): condiciona F7. *D-16 quedó resuelto: repo separado.*
5. Decidir **D-11** (clave de firma) antes de la primera instalación y **D-12** (telemetría) antes del piloto.
6. Escribir el contrato de API definitivo y validarlo contra `gasmanager/urls.py` (F0).
7. Crear el proyecto Flutter y resolver el spike de autenticación **antes** de maquetar pantallas.

---

## 14. Estado de las preguntas

### 14.1 Cerradas con las respuestas del dueño

| # | Tema | Resolución |
|---|---|---|
| P-1 | Versión de Android | **No es un problema.** Teléfonos modernos y la PWA nunca falló. Se fija `minSdk 26`, ajustable en el build |
| P-2 | Login | **Usuario y contraseña, igual que la web.** El login por teléfono nunca estuvo pedido |
| P-3 | 2FA | **Fuera de alcance por ahora.** El endpoint debe, igual, responder explícito si una cuenta lo tiene activo |
| P-4 | Distribución del APK | **Lo sirve el propio Django**, en el mismo dominio |
| P-5 | Sesión de 48 h | Se acepta tal cual. **No se alarga ni se toca** (auth está fuera de alcance). Regla de la app: la cola offline **sobrevive** a la expiración (401 → pausar cola, pedir re-login, reanudar) |
| P-7 | Alcance de "editar pedido" | **Paridad con la PWA:** se expone la misma edición que ya ofrece el botón "Editar Pedido", sin recortes |
| P-9 | Recuperación de contraseña | **No se agrega.** Si la web no lo tiene, la app tampoco |
| P-10 | Evidencia de cliente | **Fuera de alcance.** No está implementado y no es cosa del usuario |
| P-11 | Alcance visual | Resuelto por la regla de paridad (§2): se replica exactamente lo que ya muestra la web |
| P-12 | Nombre e ícono | **No se diseña nada nuevo:** se reutilizan los de la PWA |
| P-13 | Botón "abrir en Google Maps" | **No se agrega** (no existe en la web) |
| P-14 | Tema visual | **No se inventa**: mismo esquema de la PWA |
| P-15 | Usuario desactivado | Sin borrado remoto. Si el servidor rechaza la sesión, la app cierra sesión y limpia la caché local |
| P-16 | ¿El jefe usa la app? | No. App interna para camioneros; el jefe usa el panel web |
| P-18 | ¿"Tomar pedido" sin conexión? | **No.** Es la única acción donde los dos camioneros pueden pisarse; sin conexión se permite todo lo demás (entregar, cancelar, devolver, tarreo) |

### 14.2 Verificado directamente en el código (ya no son incógnitas)

| # | Hallazgo verificado | Implicación para la API nueva |
|---|---|---|
| P-6 | `axes 7.0.1` define `AXES_LOCKOUT_PARAMETERS` por defecto como `["ip_address"]`, y el proyecto no lo configura → **el bloqueo es por IP**, no por usuario | Riesgo **heredado de la web** (el camionero ya entra desde el móvil), no introducido por la app. Mitigación del lado app: no reintentar tras el bloqueo, mostrarlo con claridad y evitar gastar intentos |
| P-8 | `DetallePedidoForm._configurar_campo_descuento()` → `if self.rol not in ROLES_CON_DESCUENTO: del self.fields['descuento_unitario']` | **Sin riesgo**: el campo se elimina y un POST con `descuento_unitario` es ignorado. El endpoint JSON debe replicar esa regla con `puede_otorgar_descuento()` |
| P-11 | `partials/_entregas_cards.html` muestra: contador, secciones **En Ruta** y **Pendientes**, N° pedido, desglose con descuento, dirección, sector, y los botones **MARCAR ENTREGADO / CANCELAR ENTREGA / Editar Pedido / DEVOLVER PEDIDO** | Es el contrato visual exacto a replicar (§2, regla de paridad) |
| P-2 | `views/auth.py` → `login_view` autentica solo con `username` + contraseña; el 2FA depende de `Usuario.totp_activo` (opcional por cuenta). No existe ningún login alternativo | Login solo con usuario y contraseña; sin endpoint de traducción por teléfono |

### 14.3 Sigue pendiente (nada más)

| ID | Tema | Cuándo decidirlo |
|---|---|---|
| D-6 | Base legal del seguimiento GPS | Investigación con la jefa; bloquea F9 |
| D-11 | Custodia y respaldo del `keystore.jks` | **Antes de la primera instalación** |
| D-12 | Telemetría de fallos (Sentry/Crashlytics) | Antes del piloto (F8) |
| D-13 | Cómo se avisa de una versión nueva | Con `GET /api/v1/version/` (F7) |
| D-14 | ¿Teléfono de la empresa o del camionero? | Antes de comprar equipos |
| D-15 | Qué se considera "jornada" | Solo bloquea F9 |

### 14.4 Dudas reales que quedan

| # | Duda | Detalle |
|---|---|---|
| **P-17** | **CSRF y `Origin` en los POST nativos** | Este es el **riesgo técnico #1 de F0**. Al reutilizar sesión, Django exige `X-CSRFToken` **y**, en HTTPS, un `Referer`/`Origin` que coincida con `CSRF_TRUSTED_ORIGINS`; una petición nativa no envía ninguno de los dos. Solución esperada: que la app envíe `Origin: https://<host>` y el token CSRF. **Hay que probarlo en el spike antes de comprometer la arquitectura.** Plan B si falla (a evaluar, ambos con costo): `@csrf_exempt` solo en `/api/v1/` (debilita CSRF y hay que justificarlo) o token auth (toca autenticación, hoy prohibido) |
| **P-19** | **¿Dónde se prueba la API antes de producción?** | El cambio va al mismo repo que sirve la web en producción. ¿Hay entorno de pruebas, o se valida en local con SQLite y se despliega directo a Render? Afecta cuánto se puede arriesgar en cada iteración |
| **P-20** | **Piloto (F8): ¿quién lo prueba, cuánto tiempo y con qué criterio de éxito?** | Define si el piloto es 1 camionero por 1 semana o los dos en paralelo, y qué incidencias obligan a volver a la PWA |
| **D-17** | **Cómo se versiona un APK de ~20 MB sin inflar git** | Si cada release sobrescribe el mismo archivo, el historial crece para siempre. Opciones: un único `/apk/camionero.apk` sobrescrito (sin historial del binario), Git LFS, o un disco persistente de Render (de pago) |

**Recomendación aparte, fuera del alcance de la app:** si algún día se quiere evitar que un bloqueo de `axes` afecte a una IP móvil compartida (CGNAT), la solución es `AXES_LOCKOUT_PARAMETERS = [["username", "ip_address"]]`. Eso toca autenticación y requiere autorización expresa del dueño; **no forma parte de este proyecto**.

---

## 15. Regla de oro para todo el desarrollo

> **Si no está en la web, no está en la app.**
>
> La paridad con la PWA manda sobre cualquier idea de mejora. Cualquier propuesta que agregue una pantalla, un botón, un campo o una función que el camionero no tenga hoy en el navegador queda fuera hasta que el dueño lo pida como feature nueva.

---

## 16. Skills de Flutter instaladas (locales al proyecto)

Instaladas el 2026-10-06 desde el paquete **oficial del equipo de Flutter**: `flutter/agent-plugins` (GitHub: `flutter/agent-plugins`).

- **Ubicación:** `mobile/.agents/skills/` — instalación **local al proyecto**, no global.
- **Lockfile:** `mobile/skills-lock.json` (permite restaurar con `skills experimental_install`).
- **Registro:** `C:\Users\tokyo-3\.agents\skills\` sigue siendo el ámbito global y no se tocó.

| Skill | Para qué en este proyecto | Fase |
|---|---|---|
| `flutter-apply-architecture-best-practices` | Capas UI / lógica / datos → §7 | F0–F1 |
| `flutter-setup-declarative-routing` | `go_router`, base de la barra de 4 pestañas (§2.1) | F1 |
| `flutter-use-http-package` | Patrones de red: validación de `statusCode`, excepciones explícitas, parseo en isolate | F1 |
| `flutter-implement-json-serialization` | Modelos `fromJson`/`toJson` contra `/api/v1/` | F1 |
| `flutter-build-responsive-layout` | La app es una columna tipo la PWA (540 px) | F1 |
| `flutter-fix-layout-issues` | Depurar `RenderFlex overflowed` | transversal |
| `flutter-add-widget-preview` | Iterar la UI espejo de la PWA sin compilar todo | F1–F6 |
| `flutter-add-widget-test` | Tests de UI por pantalla | F2+ |
| `flutter-add-integration-test` | Flujo completo: login → tomar → entregar | F3+ |
| `dart-add-unit-test` | Casos de uso y `SyncEngine` | F3 |
| `dart-generate-test-mocks` | Simular la API y el repositorio (clave para el offline) | F3 |
| `dart-run-static-analysis` | `dart analyze` + `dart fix --apply` antes de cada commit | transversal |
| `dart-fix-runtime-errors` | Depurar con stack trace real | transversal |
| `dart-resolve-package-conflicts` | Cuando `pub get` se trabe | transversal |

**Evaluación de seguridad del instalador:** las 14 salieron `Safe` con 0 alertas de Socket. 13 con riesgo `Low`; `flutter-use-http-package` marcada `High` por el evaluador Gen. Revisé su contenido: es guía estándar de `http` (permiso `INTERNET`, `jsonDecode`, `compute` para parsear). El flag alto se explica por su capacidad de red, no por contenido sospechoso. **Aun así, el instalador advierte que las skills se ejecutan con permisos completos del agente: revisar antes de usar.**

**Advertencia de alcance:** `flutter-use-http-package` enseña el paquete **`http`**, y el plan usa **`dio`** (§7) porque necesitamos cookies + interceptores (`Idempotency-Key`, CSRF, reintentos). La skill sirve por sus patrones, no por el paquete. Si alguna vez se decide simplificar a `http`, habría que implementar el manejo de cookies a mano.

**Descartadas a propósito:** `flutter-setup-localization` (la app es solo español), `dart-setup-ffi-assets`, `dart-use-ffigen`, `dart-build-cli-app`, `dart-use-doc-examples`, `dart-migrate-to-checks-package`, `dart-collect-coverage`, `dart-write-documentation`, `dart-use-path-package`, `dart-use-primary-constructors`, `dart-use-pattern-matching`.

---

## 17. Entorno de desarrollo

### 17.1 Estado inicial (verificado el 2026-10-06)

**El toolchain no estaba instalado en esta máquina.** Sin esto no se puede compilar ni el esqueleto de F1.

| Componente | Estado inicial |
|---|---|
| Git | ✅ `C:\Program Files\Git\cmd\git.exe` |
| Flutter SDK | ❌ no encontrado (`C:\flutter`, `C:\src\flutter` y el perfil: todo vacío) |
| Dart | ❌ no está en el PATH |
| Android SDK (`adb`, platform-tools) | ❌ no encontrado; `ANDROID_HOME` y `ANDROID_SDK_ROOT` vacíos |
| Android Studio | ❌ no instalado |
| JDK | ⚠️ solo **Java 8** (`C:\Program Files (x86)\Common Files\Oracle\Java\java8path`), insuficiente: se exige **JDK 17+** |
| Gestores de paquetes | ❌ sin `winget`, `choco` ni `scoop` |

### 17.2 Instalación elegida: portable, sin administrador

Sin gestores de paquetes, se instala por **archivos comprimidos dentro del perfil del usuario**. Ventaja: cero permisos de administrador y todo queda en rutas predecibles.

| Componente | Ruta | Origen |
|---|---|---|
| Flutter SDK **3.47.6** (Dart 3.13.5) | `%USERPROFILE%\dev\flutter` | `storage.googleapis.com/flutter_infra_release` |
| JDK **17** (Temurin) | `%USERPROFILE%\dev\jdk17` | Adoptium |
| Android SDK (cmdline-tools) | `%USERPROFILE%\dev\android-sdk` | `dl.google.com/android/repository` |

**Por qué no Android Studio:** pesa varios GB y su aporte principal (SDK, emulador y JDK) se obtiene por separado. Para un proyecto Android-only que se prueba en teléfono real, las `cmdline-tools` alcanzan. Si más adelante se quiere emulador, Android Studio se agrega después sin desinstalar nada.

**Variables de entorno (nivel usuario, no sistema):** `PATH` += `dev\flutter\bin`; `JAVA_HOME` = `dev\jdk17`; `ANDROID_HOME` = `dev\android-sdk`.

### 17.3 Entorno de trabajo: VS Code, sin Android Studio

**Decidido por el dueño:** se desarrolla **dentro de VS Code**. Android Studio no se instala.

| Pieza | Rol |
|---|---|
| Extensión **Flutter** (`Dart-Code.flutter`) | Hot reload, depuración, `flutter doctor` y selección de dispositivo integrados |
| Extensión **Dart** (`Dart-Code.dart-code`) | Análisis, autocompletado y formato. Viene como dependencia de la anterior |
| `android-sdk\cmdline-tools` | Compila y firma el APK |
| `.vscode/settings.json` | Apunta a `dev\flutter` y fija el formato en 100 columnas |

**Aclaración importante:** Android Studio y el SDK de Android **no son lo mismo**. Lo único que aporta Android Studio y que aquí no se instala es la **interfaz gráfica** y el **emulador**. El compilador (`platform-tools`, `build-tools`, `platforms`) es idéntico en ambos casos y se instala por línea de comandos. Sin ese SDK no se puede generar el APK, aunque se programe en VS Code.

**Recomendado:** un **teléfono Android real** para probar antes del piloto.

### 17.4 Resultado verificado (2026-10-06)

```
[√] Flutter 3.47.6 (channel stable) · Dart 3.13.5 · DevTools 2.60.0
[√] Android toolchain — Android SDK 36.0.0
[√] adb 1.0.41 (platform-tools 37.0.1)
```

| Pieza | Ruta | Versión |
|---|---|---|
| Flutter SDK | `%USERPROFILE%\dev\flutter` | 3.47.6 |
| Dart | incluido en Flutter | 3.13.5 |
| JDK | `%USERPROFILE%\dev\jdk17` | Temurin 17 |
| Android SDK | `%USERPROFILE%\dev\android-sdk` | platform 36 · build-tools 36.0.0 · platform-tools 37.0.1 |
| Extensiones VS Code | — | Flutter + Dart (`Dart-Code`) |

**Android Studio no está instalado y no hace falta.** Se usó `cmdline-tools`: la parte de línea de comandos del SDK, sin interfaz gráfica ni emulador.

**Avisos que quedaron en `flutter doctor`:** Chrome y Visual Studio. Son irrelevantes — web, windows/linux/macos desktop e iOS quedaron desactivados con `flutter config`, así que el proyecto es Android-only.

**Dos cosas que requieren intervención manual:**
1. **Reiniciar VS Code** para que herede las nuevas variables de `PATH` (`flutter`, `dart`, `adb`).
2. En terminales nuevas, si `flutter` no aparece, usar la ruta absoluta `%USERPROFILE%\dev\flutter\bin\flutter.bat`.

**Cambio de API a tener en cuenta:** en esta versión de las `cmdline-tools`, `sdkmanager` está **deprecado** y `--licenses` **ya no es necesario** (las licencias se gestionan solas). El reemplazo es el CLI `android sdk install|list|remove|update`. Las guías antiguas que dicen `sdkmanager --licenses` ya no aplican.

### 17.5 Problemas encontrados al compilar (y su solución)

| Síntoma | Causa real | Solución aplicada |
|---|---|---|
| `Package ndk not found. Package 28.2.13676358 not found` y luego `Android sdkmanager did not install NDK` | El **`sdkmanager.bat` deprecado rompe cualquier argumento que contenga `;`**: lo parte en dos. Por eso Gradle no podía instalar el NDK solo | Instalar los paquetes con el CLI nuevo: `android sdk install "ndk;28.2.13676358"`. **Este bug afectará a cualquier proyecto Flutter en esta máquina** |
| `avdmanager is missing from the Android SDK` (aviso de VS Code al crear un emulador) | VS Code se inició **antes** de definir `ANDROID_HOME`, así que la extensión no veía el SDK. El archivo `avdmanager.bat` siempre existió y funciona | `flutter config --android-sdk <ruta>`: queda guardado en la configuración de Flutter y no depende de variables de entorno. Requiere reiniciar VS Code |
| `only understands SDK XML versions up to 3 but an SDK XML file of version 4 was encountered` | Las `cmdline-tools` nuevas generan XML v4 y AGP entiende v3 | Solo un aviso. La compilación funciona |

**Verificado el 2026-10-06:** `flutter build apk --debug` → `√ Built build\app\outputs\flutter-apk\app-debug.apk`. El toolchain de Android queda validado de punta a punta.

### 17.6 Emulador: qué falta y por qué no se recomienda

Crear un AVD requiere **cuatro** piezas, no una:

1. `avdmanager` ✅ (ya está, el problema era la ruta del SDK)
2. Paquete `emulator` ❌ (~350 MB)
3. Una **imagen de sistema** ❌ (~1,5–2 GB)
4. **Aceleración por hardware** ❌

Estado de la máquina verificado: el procesador soporta VT-x (`VMMonitorModeExtensions=True`, `VirtFirmwareEnabled=True`) pero **`HypervisorPresent=False`**: no hay hypervisor activo. Habilitar *Windows Hypervisor Platform* exige **permisos de administrador y reiniciar Windows**, así que es un paso manual del dueño. Sin eso el emulador corre por software y resulta inusable (minutos de arranque, bloqueos).

Aun con todo instalado, el emulador **no reproduce lo que más importa en esta app**: notificaciones con la app cerrada, exención de optimización de batería y, si se aprueba, el servicio en primer plano del GPS (§6). Esas tres cosas solo se prueban en un teléfono real.

**Recomendación:** probar en **teléfono Android por USB** (depuración USB activada). Cero descargas y cubre el comportamiento real.

---

## 18. Estado de implementación (2026-10-06)

| Fase | Estado |
|---|---|
| Toolchain | ✅ Flutter 3.47.6 + Android SDK 36 (§17.4) |
| Repositorio | ✅ `gas_facil_movil`, rama `main` |
| **F0** contrato de API | ✅ `gas_project/docs/API_MOVIL.md`; el *spike* de CSRF quedó resuelto |
| **F1** login + listado | ✅ probado en el teléfono contra el API real |
| **F2** las cuatro acciones | ✅ API y app; probado de punta a punta (tomar un pedido) |
| Sesión persistente | ✅ `flutter_secure_storage` (Keystore), confirmada contra `/auth/perfil/` y con la cookie cifrada en el disco del teléfono |
| **F4** `tarreo/` y `balones/` | ✅ API (13 tests) y app: el Tarreo vende contra el catálogo real, sin precios inventados |
| **F4** revisión de fidelidad | ✅ el Tarreo quedó igual a la PWA: total fijo arriba, tres pasos numerados, botón AGREGAR con contador que aparece después, etiqueta de tipo de gas y modal de confirmación con productos, método y total |
| **F6** `resumen-hoy/` e `historial/` | ✅ API (11 tests) y app: historial del mes con detalle por día, y el reloj del inicio ahora es el del servidor |
| Idempotencia (`Idempotency-Key`) | ⏳ requiere una migración en el servidor (§8 del contrato) |

### 18.1 Qué existe hoy en `lib/`

| Archivo | Contenido |
|---|---|
| `main.dart` / `app.dart` | Arranque, reapertura de sesión y contenedor con la barra de cuatro destinos |
| `core/config/api_config.dart` | `baseUrl` y `Origin` por `--dart-define` |
| `core/error/error_api.dart` | Error de dominio con el catálogo de códigos del §5.2 |
| `core/storage/almacen_sesion.dart` | Credencial de sesión en el almacén cifrado del sistema |
| `core/time/reloj_servidor.dart` | Desfase contra `servidor_ahora`: el reloj del teléfono no se usa |
| `data/api_cliente.dart` | Sobre del contrato, cookies, doble envío CSRF, las cuatro acciones, el catálogo de balones, la venta tarreo y el historial |
| `data/controlador_entregas.dart` | Único dueño de los datos del panel, compartido por las dos pantallas |
| `data/controlador_balones.dart` | Único dueño del catálogo de balones; los precios son los del servidor |
| `models/` | `Pedido`, `LineaPedido`, `Usuario`, `ResumenEntregas`, `HistorialMes`/`DiaHistorial`/`DetalleDia` y formato de CLP |
| `screens/` | Login, Inicio, Entregas, Mis Entregas, Tarreo, Historial y Detalle del día |
| `theme/`, `widgets/` | Espejo de la PWA (Bootstrap 5) |

### 18.2 Lo que todavía NO hace (a propósito)

- **Sin idempotencia**: un reintento tras un corte de señal puede repetir una acción. Requiere `Idempotency-Key` en el servidor (§8) más la cola local.
- **Sin cola offline ni caché**: con el servidor caído solo se ve la última lista conocida, marcada como vieja.
- **El detalle de un día no tiene el botón "Ver vista de hoy"** que la web muestra cuando el día es hoy: en la app se llega por la pestaña "Mis Entregas", que ya está siempre en la barra.
- **`GET /api/v1/resumen-hoy/` no lo consume la app**: `/entregas/` ya trae esos datos y el inicio de la web no muestra números en las tarjetas. Queda para el refresco liviano del inicio.
- **Después de guardar, el Tarreo vuelve al inicio**; la web redirige a "Mis Entregas" (`entregas_mias`). Decisión del dueño: el camionero termina la venta y vuelve al menú.
- **El Tarreo no ofrece "Transferencia"** aunque el API lo acepte: la web solo muestra Efectivo y Tarjeta, y la app copia la pantalla, no el modelo. Tampoco hay método preseleccionado (en la web el campo es obligatorio y empieza vacío).
- "Editar Pedido" (venta extra) sigue siendo un aviso: el contrato todavía no tiene ese endpoint.
- **Ninguna pantalla usa ya datos inventados**: `DatosMock` se borró con F4. `grep -r DatosMock lib/` no debe devolver nada.

### 18.3 Cómo depurar en el teléfono (sin pedir capturas)

> El procedimiento completo —emparejamiento por wifi, `adb reverse`, espejo con scrcpy y los problemas ya vistos— está en **`docs/DEPURACION_TELEFONO.md`**.

El teléfono responde a `adb`, así que el error se inspecciona directo:

| Necesidad | Comando |
|---|---|
| Ver la pantalla del teléfono | `adb shell screencap -p /sdcard/x.png` + `adb pull /sdcard/x.png` |
| Ver el log del sistema | `adb logcat -d -t 400` |
| Qué ventana tiene el foco | `adb shell dumpsys window \| Select-String "mCurrentFocus"` |
| Tocar la pantalla por coordenadas | `adb shell input tap <x> <y>` (resolución: `adb shell wm size`) |
| Instalar y lanzar sin REPL | `adb install -r <apk>` + `adb shell monkey -p cl.kimgas.gas_facil_movil -c android.intent.category.LAUNCHER 1` |

**Lección del primer error real:** `flutter analyze` pasó limpio y la app **igual crasheó** en el teléfono. El análisis estático no detecta aserciones en tiempo de ejecución (`TextTheme.apply(fontSizeFactor:)` revienta si un estilo base tiene `fontSize == null`). Por eso el paso "probar en el teléfono real" no es opcional. El emulador no reproduce bien batería, notificaciones en background ni la exención de optimización, que es justo lo crítico de esta app.
