# Catálogo de Precios y Economía de Objetos (R.E.P.O.)

Documento de referencia canónico extraído directamente de los archivos de juego originales de **R.E.P.O.** (`resources.assets` y `sharedassets0.assets`), correspondiente a las clases `Item`, `ItemAttributes` y `ShopManager`.

---

## 1. Mecánica de Precios en la Tienda (*Service Station*)

En R.E.P.O., los precios de los objetos no son fijos, sino que cada objeto está vinculado a un ScriptableObject de tipo `Value` que define un rango de valor base `[valueMin, valueMax]`.

### Fórmula de Cálculo Base
Al generarse el inventario de la tienda en `ItemAttributes.GetValue()`, el juego calcula el costo en miles de dólares (`$K`) con la siguiente fórmula:

$$\text{Precio Base en Tienda (\$K)} = \left\lceil \frac{\max(\text{Random}(valueMin, valueMax) \times 4.0,\; 1000)}{1000} \right\rceil$$

En la interfaz de usuario de la tienda, el precio se muestra en pantalla como un número negativo con el sufijo `K` (por ejemplo: `-$2K`, `-$18K`, `-$38K`).

### Modificadores Dinámicos de la Tienda
* **Mejoras de Jugador (`item_upgrade`):**
  El precio mostrado en esta tabla es el **costo base**. Cada compra adicional de la misma mejora incrementa su precio un **+50%** del valor base acumulativo (`+50% * compras_anteriores`). Además, existe un descuento del 10% por cada jugador adicional en la sala (hasta 6 jugadores).
* **Botiquines de Salud (`healthPack`):**
  El precio se incrementa un **+5%** por cada nivel superado en la partida (`+5% * niveles_completados`, hasta un máximo de 15 niveles).
* **Cristal de Poder (`power_crystal`):**
  El precio se incrementa un **+20%** por cada nivel superado en la partida (`+20% * niveles_completados`, hasta un máximo de 15 niveles).

---

## 2. Niveles de Valor (*Value Tiers*)

Los objetos del juego se clasifican en los siguientes niveles de valor base predefinidos:

| Nivel de Valor (*Tier*) | Rango Base (`valueMin` - `valueMax`) | Rango en Tienda (`$K`) | Tipo de Objetos |
|---|:---:|:---:|---|
| `Very Cheap` | 250 – 500 | **$1K – $2K** | Granada humana |
| `Cheap-` | 300 – 450 | **$2K** | Granadas y minas básicas, mejora de energía |
| `Cheap` | 500 – 650 | **$2K – $3K** | Granada explosiva, minas |
| `Health Pack Small` | 500 – 750 | **$2K – $3K** | Botiquín pequeño |
| `Cheap+` | 850 – 1,100 | **$4K – $5K** | Rastreador de extracción, mejoras de salud/lanzamiento |
| `Crystal` | 1,000 – 1,500 | **$4K – $6K** | Cristal de poder |
| `Health Pack Medium`| 1,000 – 1,500 | **$4K – $6K** | Botiquín mediano |
| `Cheap++` | 1,200 – 2,000 | **$5K – $8K** | Cubo patitos, rastreador valiosos, mejoras sprint/fuerza/agarre |
| `Medium` | 2,000 – 3,000 | **$8K – $12K** | Dron torque, soplador, martillo inflable, saltos extra |
| `Health Pack Large` | 2,000 – 3,000 | **$8K – $12K** | Botiquín grande |
| `Medium+` | 3,500 – 4,500 | **$14K – $18K** | Carro pequeño, armas tranquilizantes/aturdir, bastón gravedad cero |
| `Medium++` | 4,500 – 5,000 | **$18K – $20K** | Pistola, espada, puente de fase, semiscooter pequeño |
| `High` | 5,500 – 7,500 | **$22K – $30K** | Bastón eléctrico, drones indestructibles/gravedad cero, bastones |
| `High+` | 9,500 – 12,000 | **$38K – $48K** | Escopeta, pistola láser, bate béisbol, mazo pesado, carros pesados |
| `Expensive` | 18,000 – 25,000 | **$72K – $100K** | Utilidades especiales de alto costo |

---

## 3. Catálogo de Objetos por Categoría

### Explosivos y Granadas

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Grenade Human** | Granada humana | `Item Grenade Human` | `Very Cheap` | 250 – 500 | **$1K – $2K** |
| **Grenade Duct Taped** | Granada con cinta adhesiva | `Item Grenade Duct Taped` | `Cheap-` | 300 – 450 | **$2K – $2K** |
| **Grenade Shockwave** | Granada de onda de choque | `Item Grenade Shockwave` | `Cheap-` | 300 – 450 | **$2K – $2K** |
| **Grenade Stun** | Granada aturdidora | `Item Grenade Stun` | `Cheap-` | 300 – 450 | **$2K – $2K** |
| **Grenade Explosive** | Granada explosiva | `Item Grenade Explosive` | `Cheap` | 500 – 650 | **$2K – $3K** |
| **Mine Explosive** | Mina explosiva | `Item Mine Explosive` | `Cheap` | 500 – 650 | **$2K – $3K** |
| **Mine Shockwave** | Mina de choque | `Item Mine Shockwave` | `Cheap` | 500 – 650 | **$2K – $3K** |
| **Mine Stun** | Mina aturdidora | `Item Mine Stun` | `Cheap` | 500 – 650 | **$2K – $3K** |

### Armas de Fuego

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Gun Shockwave** | Pistola de choque | `Item Gun Shockwave` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Gun Stun** | Pistola aturdidora | `Item Gun Stun` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Gun Tranq** | Pistola tranquilizante | `Item Gun Tranq` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Gun Handgun** | Pistola | `Item Gun Handgun` | `Medium++` | 4500 – 5000 | **$18K – $20K** |
| **Gun Laser** | Pistola láser (Photon Blaster) | `Item Gun Laser` | `High+` | 9500 – 12000 | **$38K – $48K** |
| **Gun Shotgun** | Escopeta | `Item Gun Shotgun` | `High+` | 9500 – 12000 | **$38K – $48K** |

### Armas Cuerpo a Cuerpo (Melee)

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Melee Inflatable Hammer** | Martillo inflable | `Item Melee Inflatable Hammer` | `Medium` | 2000 – 3000 | **$8K – $12K** |
| **Melee Frying Pan** | Sartén | `Item Melee Frying Pan` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Melee Sword** | Espada | `Item Melee Sword` | `Medium++` | 4500 – 5000 | **$18K – $20K** |
| **Melee Stun Baton** | Bastón eléctrico | `Item Melee Stun Baton` | `High` | 5500 – 7500 | **$22K – $30K** |
| **Melee Baseball Bat** | Bate de béisbol | `Item Melee Baseball Bat` | `High+` | 9500 – 12000 | **$38K – $48K** |
| **Melee Sledge Hammer** | Mazo pesado | `Item Melee Sledge Hammer` | `High+` | 9500 – 12000 | **$38K – $48K** |

### Bastones (Staves)

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Staff Zero Gravity** | Bastón gravedad cero | `Item Staff Zero Gravity` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Staff Torque** | Bastón torque | `Item Staff Torque` | `High` | 5500 – 7500 | **$22K – $30K** |
| **Staff Void** | Bastón del vacío | `Item Staff Void` | `High` | 5500 – 7500 | **$22K – $30K** |

### Drones y Orbes

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Drone Torque** | Dron torque | `Item Drone Torque` | `Medium` | 2000 – 3000 | **$8K – $12K** |
| **Drone Battery** | Dron batería | `Item Drone Battery` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Drone Feather** | Dron pluma | `Item Drone Feather` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Drone Indestructible** | Dron indestructible | `Item Drone Indestructible` | `High` | 5500 – 7500 | **$22K – $30K** |
| **Drone Zero Gravity** | Dron gravedad cero | `Item Drone Zero Gravity` | `High` | 5500 – 7500 | **$22K – $30K** |
| **Orb Zero Gravity** | Orbe gravedad cero | `Item Orb Zero Gravity` | `High+` | 9500 – 12000 | **$38K – $48K** |

### Transporte y Carros

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Cart Small** | Carro pequeño (Pocket C.A.R.T.) | `Item Cart Small` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Vehicle Semiscooter** | Semiscooter | `Item Vehicle Semiscooter` | `Medium++` | 4500 – 5000 | **$18K – $20K** |
| **Vehicle Semiscooter Small** | Semiscooter pequeño | `Item Vehicle Semiscooter Small` | `Medium++` | 4500 – 5000 | **$18K – $20K** |
| **Cart Cannon** | Carro cañón | `Item Cart Cannon` | `High+` | 9500 – 12000 | **$38K – $48K** |
| **Cart Laser** | Carro láser | `Item Cart Laser` | `High+` | 9500 – 12000 | **$38K – $48K** |
| **Cart Medium** | Carro mediano | `Item Cart Medium` | `High+` | 9500 – 12000 | **$38K – $48K** |

### Salud y Curación

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Health Pack Small** | Botiquín pequeño | `Item Health Pack Small` | `Health Pack Small` | 500 – 750 | **$2K – $3K** |
| **Health Pack Medium** | Botiquín mediano | `Item Health Pack Medium` | `Health Pack Medium` | 1000 – 1500 | **$4K – $6K** |
| **Health Pack Large** | Botiquín grande | `Item Health Pack Large` | `Health Pack Large` | 2000 – 3000 | **$8K – $12K** |
| **ReviveItem** | Desfibrilador / Revivir | `Item ReviveItem` | `High+` | 9500 – 12000 | **$38K – $48K** |

### Mejoras de Jugador (Upgrades)

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Upgrade Player Energy** | Mejora de energía | `Item Upgrade Player Energy` | `Cheap-` | 300 – 450 | **$2K – $2K** |
| **Upgrade Player Health** | Mejora de vida | `Item Upgrade Player Health` | `Cheap+` | 850 – 1100 | **$4K – $5K** |
| **Upgrade Player Tumble Launch** | Mejora lanzamiento rodando | `Item Upgrade Player Tumble Launch` | `Cheap+` | 850 – 1100 | **$4K – $5K** |
| **Upgrade Death Head Battery** | Mejora batería de cabeza | `Item Upgrade Death Head Battery` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Upgrade Player Crouch Rest** | Mejora descanso agachado | `Item Upgrade Player Crouch Rest` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Upgrade Player Grab Range** | Mejora alcance de agarre | `Item Upgrade Player Grab Range` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Upgrade Player Grab Strength** | Mejora fuerza de agarre | `Item Upgrade Player Grab Strength` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Upgrade Player Sprint Speed** | Mejora velocidad sprint | `Item Upgrade Player Sprint Speed` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Upgrade Map Player Count** | Mejora mapa jugadores | `Item Upgrade Map Player Count` | `Medium` | 2000 – 3000 | **$8K – $12K** |
| **Upgrade Player Extra Jump** | Mejora salto extra | `Item Upgrade Player Extra Jump` | `Medium` | 2000 – 3000 | **$8K – $12K** |
| **Upgrade Player Tumble Wings** | Mejora alas de planeo | `Item Upgrade Player Tumble Wings` | `Medium` | 2000 – 3000 | **$8K – $12K** |
| **Upgrade Player Tumble Climb** | Mejora trepar rodando | `Item Upgrade Player Tumble Climb` | `Medium++` | 4500 – 5000 | **$18K – $20K** |

### Herramientas y Utilidad

| Objeto (EN) | Objeto (ES) | Clave Interna (`ItemKeys`) | Tier | Rango Base | Costo Tienda |
|---|---|---|:---:|:---:|:---:|
| **Extraction Tracker** | Rastreador de extracción | `Item Extraction Tracker` | `Cheap+` | 850 – 1100 | **$4K – $5K** |
| **Power Crystal** | Cristal de poder | `Item Power Crystal` | `Crystal` | 1000 – 1500 | **$4K – $6K** |
| **Duck Bucket** | Cubo de patitos | `Item Duck Bucket` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Valuable Tracker** | Rastreador de valiosos | `Item Valuable Tracker` | `Cheap++` | 1200 – 2000 | **$5K – $8K** |
| **Leaf Blower** | Soplador de hojas | `Item Leaf Blower` | `Medium` | 2000 – 3000 | **$8K – $12K** |
| **Rubber Duck** | Patito de goma | `Item Rubber Duck` | `Medium+` | 3500 – 4500 | **$14K – $18K** |
| **Phase Bridge** | Puente de fase | `Item Phase Bridge` | `Medium++` | 4500 – 5000 | **$18K – $20K** |
| **WalkieTalkieBox** | Caja de walkie-talkies | `Item WalkieTalkieBox` | `High` | 5500 – 7500 | **$22K – $30K** |

---

## 4. Tabla Maestra de Precios (Ordenada de Menor a Mayor Costo)

| Costo Tienda | Objeto | Clave Interna (`ItemKeys`) | Categoría | Tier | Rango Base |
|:---:|---|---|---|:---:|:---:|
| **$1K – $2K** | **Grenade Human** (Granada humana) | `Item Grenade Human` | Explosivos y Granadas | `Very Cheap` | 250 – 500 |
| **$2K – $2K** | **Grenade Duct Taped** (Granada con cinta adhesiva) | `Item Grenade Duct Taped` | Explosivos y Granadas | `Cheap-` | 300 – 450 |
| **$2K – $2K** | **Grenade Shockwave** (Granada de onda de choque) | `Item Grenade Shockwave` | Explosivos y Granadas | `Cheap-` | 300 – 450 |
| **$2K – $2K** | **Grenade Stun** (Granada aturdidora) | `Item Grenade Stun` | Explosivos y Granadas | `Cheap-` | 300 – 450 |
| **$2K – $2K** | **Upgrade Player Energy** (Mejora de energía) | `Item Upgrade Player Energy` | Mejoras de Jugador (Upgrades) | `Cheap-` | 300 – 450 |
| **$2K – $3K** | **Grenade Explosive** (Granada explosiva) | `Item Grenade Explosive` | Explosivos y Granadas | `Cheap` | 500 – 650 |
| **$2K – $3K** | **Health Pack Small** (Botiquín pequeño) | `Item Health Pack Small` | Salud y Curación | `Health Pack Small` | 500 – 750 |
| **$2K – $3K** | **Mine Explosive** (Mina explosiva) | `Item Mine Explosive` | Explosivos y Granadas | `Cheap` | 500 – 650 |
| **$2K – $3K** | **Mine Shockwave** (Mina de choque) | `Item Mine Shockwave` | Explosivos y Granadas | `Cheap` | 500 – 650 |
| **$2K – $3K** | **Mine Stun** (Mina aturdidora) | `Item Mine Stun` | Explosivos y Granadas | `Cheap` | 500 – 650 |
| **$4K – $5K** | **Extraction Tracker** (Rastreador de extracción) | `Item Extraction Tracker` | Herramientas y Utilidad | `Cheap+` | 850 – 1100 |
| **$4K – $5K** | **Upgrade Player Health** (Mejora de vida) | `Item Upgrade Player Health` | Mejoras de Jugador (Upgrades) | `Cheap+` | 850 – 1100 |
| **$4K – $5K** | **Upgrade Player Tumble Launch** (Mejora lanzamiento rodando) | `Item Upgrade Player Tumble Launch` | Mejoras de Jugador (Upgrades) | `Cheap+` | 850 – 1100 |
| **$4K – $6K** | **Health Pack Medium** (Botiquín mediano) | `Item Health Pack Medium` | Salud y Curación | `Health Pack Medium` | 1000 – 1500 |
| **$4K – $6K** | **Power Crystal** (Cristal de poder) | `Item Power Crystal` | Herramientas y Utilidad | `Crystal` | 1000 – 1500 |
| **$5K – $8K** | **Duck Bucket** (Cubo de patitos) | `Item Duck Bucket` | Herramientas y Utilidad | `Cheap++` | 1200 – 2000 |
| **$5K – $8K** | **Upgrade Death Head Battery** (Mejora batería de cabeza) | `Item Upgrade Death Head Battery` | Mejoras de Jugador (Upgrades) | `Cheap++` | 1200 – 2000 |
| **$5K – $8K** | **Upgrade Player Crouch Rest** (Mejora descanso agachado) | `Item Upgrade Player Crouch Rest` | Mejoras de Jugador (Upgrades) | `Cheap++` | 1200 – 2000 |
| **$5K – $8K** | **Upgrade Player Grab Range** (Mejora alcance de agarre) | `Item Upgrade Player Grab Range` | Mejoras de Jugador (Upgrades) | `Cheap++` | 1200 – 2000 |
| **$5K – $8K** | **Upgrade Player Grab Strength** (Mejora fuerza de agarre) | `Item Upgrade Player Grab Strength` | Mejoras de Jugador (Upgrades) | `Cheap++` | 1200 – 2000 |
| **$5K – $8K** | **Upgrade Player Sprint Speed** (Mejora velocidad sprint) | `Item Upgrade Player Sprint Speed` | Mejoras de Jugador (Upgrades) | `Cheap++` | 1200 – 2000 |
| **$5K – $8K** | **Valuable Tracker** (Rastreador de valiosos) | `Item Valuable Tracker` | Herramientas y Utilidad | `Cheap++` | 1200 – 2000 |
| **$8K – $12K** | **Drone Torque** (Dron torque) | `Item Drone Torque` | Drones y Orbes | `Medium` | 2000 – 3000 |
| **$8K – $12K** | **Health Pack Large** (Botiquín grande) | `Item Health Pack Large` | Salud y Curación | `Health Pack Large` | 2000 – 3000 |
| **$8K – $12K** | **Leaf Blower** (Soplador de hojas) | `Item Leaf Blower` | Herramientas y Utilidad | `Medium` | 2000 – 3000 |
| **$8K – $12K** | **Melee Inflatable Hammer** (Martillo inflable) | `Item Melee Inflatable Hammer` | Armas Cuerpo a Cuerpo (Melee) | `Medium` | 2000 – 3000 |
| **$8K – $12K** | **Upgrade Map Player Count** (Mejora mapa jugadores) | `Item Upgrade Map Player Count` | Mejoras de Jugador (Upgrades) | `Medium` | 2000 – 3000 |
| **$8K – $12K** | **Upgrade Player Extra Jump** (Mejora salto extra) | `Item Upgrade Player Extra Jump` | Mejoras de Jugador (Upgrades) | `Medium` | 2000 – 3000 |
| **$8K – $12K** | **Upgrade Player Tumble Wings** (Mejora alas de planeo) | `Item Upgrade Player Tumble Wings` | Mejoras de Jugador (Upgrades) | `Medium` | 2000 – 3000 |
| **$14K – $18K** | **Cart Small** (Carro pequeño (Pocket C.A.R.T.)) | `Item Cart Small` | Transporte y Carros | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Drone Battery** (Dron batería) | `Item Drone Battery` | Drones y Orbes | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Drone Feather** (Dron pluma) | `Item Drone Feather` | Drones y Orbes | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Gun Shockwave** (Pistola de choque) | `Item Gun Shockwave` | Armas de Fuego | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Gun Stun** (Pistola aturdidora) | `Item Gun Stun` | Armas de Fuego | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Gun Tranq** (Pistola tranquilizante) | `Item Gun Tranq` | Armas de Fuego | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Melee Frying Pan** (Sartén) | `Item Melee Frying Pan` | Armas Cuerpo a Cuerpo (Melee) | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Rubber Duck** (Patito de goma) | `Item Rubber Duck` | Herramientas y Utilidad | `Medium+` | 3500 – 4500 |
| **$14K – $18K** | **Staff Zero Gravity** (Bastón gravedad cero) | `Item Staff Zero Gravity` | Bastones (Staves) | `Medium+` | 3500 – 4500 |
| **$18K – $20K** | **Gun Handgun** (Pistola) | `Item Gun Handgun` | Armas de Fuego | `Medium++` | 4500 – 5000 |
| **$18K – $20K** | **Melee Sword** (Espada) | `Item Melee Sword` | Armas Cuerpo a Cuerpo (Melee) | `Medium++` | 4500 – 5000 |
| **$18K – $20K** | **Phase Bridge** (Puente de fase) | `Item Phase Bridge` | Herramientas y Utilidad | `Medium++` | 4500 – 5000 |
| **$18K – $20K** | **Upgrade Player Tumble Climb** (Mejora trepar rodando) | `Item Upgrade Player Tumble Climb` | Mejoras de Jugador (Upgrades) | `Medium++` | 4500 – 5000 |
| **$18K – $20K** | **Vehicle Semiscooter** (Semiscooter) | `Item Vehicle Semiscooter` | Transporte y Carros | `Medium++` | 4500 – 5000 |
| **$18K – $20K** | **Vehicle Semiscooter Small** (Semiscooter pequeño) | `Item Vehicle Semiscooter Small` | Transporte y Carros | `Medium++` | 4500 – 5000 |
| **$22K – $30K** | **Drone Indestructible** (Dron indestructible) | `Item Drone Indestructible` | Drones y Orbes | `High` | 5500 – 7500 |
| **$22K – $30K** | **Drone Zero Gravity** (Dron gravedad cero) | `Item Drone Zero Gravity` | Drones y Orbes | `High` | 5500 – 7500 |
| **$22K – $30K** | **Melee Stun Baton** (Bastón eléctrico) | `Item Melee Stun Baton` | Armas Cuerpo a Cuerpo (Melee) | `High` | 5500 – 7500 |
| **$22K – $30K** | **Staff Torque** (Bastón torque) | `Item Staff Torque` | Bastones (Staves) | `High` | 5500 – 7500 |
| **$22K – $30K** | **Staff Void** (Bastón del vacío) | `Item Staff Void` | Bastones (Staves) | `High` | 5500 – 7500 |
| **$22K – $30K** | **WalkieTalkieBox** (Caja de walkie-talkies) | `Item WalkieTalkieBox` | Herramientas y Utilidad | `High` | 5500 – 7500 |
| **$38K – $48K** | **Cart Cannon** (Carro cañón) | `Item Cart Cannon` | Transporte y Carros | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Cart Laser** (Carro láser) | `Item Cart Laser` | Transporte y Carros | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Cart Medium** (Carro mediano) | `Item Cart Medium` | Transporte y Carros | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Gun Laser** (Pistola láser (Photon Blaster)) | `Item Gun Laser` | Armas de Fuego | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Gun Shotgun** (Escopeta) | `Item Gun Shotgun` | Armas de Fuego | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Melee Baseball Bat** (Bate de béisbol) | `Item Melee Baseball Bat` | Armas Cuerpo a Cuerpo (Melee) | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Melee Sledge Hammer** (Mazo pesado) | `Item Melee Sledge Hammer` | Armas Cuerpo a Cuerpo (Melee) | `High+` | 9500 – 12000 |
| **$38K – $48K** | **Orb Zero Gravity** (Orbe gravedad cero) | `Item Orb Zero Gravity` | Drones y Orbes | `High+` | 9500 – 12000 |
| **$38K – $48K** | **ReviveItem** (Desfibrilador / Revivir) | `Item ReviveItem` | Salud y Curación | `High+` | 9500 – 12000 |
