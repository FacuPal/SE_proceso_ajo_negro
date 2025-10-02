// Esquema
CREATE CONSTRAINT frame_class_constraint IF NOT EXISTS FOR (c:FrameClass) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT frame_instance_constraint IF NOT EXISTS FOR (i:FrameInstance) REQUIRE i.id IS UNIQUE;
CREATE CONSTRAINT slot_constraint IF NOT EXISTS FOR (s:Slot) REQUIRE s.name IS UNIQUE;
CREATE CONSTRAINT slot_constraint IF NOT EXISTS FOR (s:Slot) REQUIRE s.name IS UNIQUE;
CREATE INDEX daemon_index IF NOT EXISTS FOR (d:Daemon) ON (d.name);

// ===================== Clases (FrameClass) =====================
MERGE (Rango:FrameClass {name:'Rango'})
MERGE (Etapa:FrameClass {name:'Etapa'})
MERGE (Actuador:FrameClass {name:'Actuador'})
MERGE (Lectura:FrameClass {name:'Lectura'})
MERGE (Corrida:FrameClass {name:'Corrida'})
MERGE (Alerta:FrameClass {name:'Alerta'})
MERGE (Recomendacion:FrameClass {name:'Recomendacion'})


// ===================== Slots (globales por nombre) =====================
// Comunes
MERGE (slName:Slot {name:'name'})
// MERGE (slId:Slot {name:'id'})
MERGE (slTs:Slot {name:'ts'})

// Rango
MERGE (slValorEsperado:Slot {name:'valorEsperado'})
MERGE (slTolerancia:Slot {name:'tolerancia'})
MERGE (slMinimo:Slot {name:'minimo'})
MERGE (slMaximo:Slot {name:'maximo'})

// Etapa
MERGE (slPrecedeA:Slot {name:'precedeA'})
MERGE (slConfigTemp:Slot {name:'configuracionTemperatura'})

// Actuador
MERGE (slCapacidad:Slot {name:'capacidad'})
MERGE (slActivo:Slot {name:'activo'})

// Lectura
MERGE (slTempInt:Slot {name:'temperaturaInterna'})
MERGE (slTendencia:Slot {name:'tendencia'})
MERGE (slCorrida:Slot {name:'corrida'})
MERGE (slEtapa:Slot {name:'etapa'})
MERGE (slEstado:Slot {name:'estado'})

// Corrida
// MERGE (slId:Slot {name:'id'})
MERGE (slFechaInicio:Slot {name:'fechaInicio'})
MERGE (slEtapaActual:Slot {name:'etapaActual'})
MERGE (slFechaFin:Slot {name:'fechaFin'})
MERGE (slRecomendaciones:Slot {name:'recomendaciones'})
MERGE (slAlertas:Slot {name:'alertas'})
MERGE (slActuadores:Slot {name:'actuadores'})
MERGE (slUltimaLectura:Slot {name:'ultimaLectura'})

// Alerta
MERGE (slActiva:Slot {name:'activa'})
MERGE (slExplicacion:Slot {name:'explicacion'})

// Recomendacion
MERGE (slPrioridad:Slot {name:'prioridad'})
MERGE (slConflictaCon:Slot {name:'conflictaCon'})

// ===================== Declaración de Slots por Clase =====================
// Rango
MERGE (Rango)-[:HAS_SLOT {type:'string',  cardinality:'1',   required:true}]->(slName)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slValorEsperado)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slTolerancia)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:false}]->(slMinimo)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:false}]->(slMaximo)

// Etapa
MERGE (Etapa)-[:HAS_SLOT {type:'string',  cardinality:'1',   required:true}]->(slName)
MERGE (Etapa)-[:HAS_SLOT {type:'Etapa',   cardinality:'0..1', required:false}]->(slPrecedeA)
MERGE (Etapa)-[:HAS_SLOT {type:'Rango',   cardinality:'1',   required:true}]->(slConfigTemp)

// Actuador
MERGE (Actuador)-[:HAS_SLOT {type:'string',  cardinality:'1', required:true}]->(slName)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:true}]->(slCapacidad)
MERGE (Actuador)-[:HAS_SLOT {type:'boolean', cardinality:'1', required:true}]->(slActivo)

// Lectura
MERGE (Lectura)-[:HAS_SLOT {type:'string',     cardinality:'1',   required:true}]->(slName)
MERGE (Lectura)-[:HAS_SLOT {type:'datetime',   cardinality:'1',   required:true}]->(slTs)
MERGE (Lectura)-[:HAS_SLOT {type:'float',      cardinality:'1',   required:true, range:'0.0..100.0'}]->(slTempInt)
MERGE (Lectura)-[:HAS_SLOT {type:'float',      cardinality:'1',   required:true}]->(slTendencia)
MERGE (Lectura)-[:HAS_SLOT {type:'Corrida',    cardinality:'1',   required:true}]->(slCorrida)
MERGE (Lectura)-[:HAS_SLOT {type:'Etapa',      cardinality:'1',   required:true}]->(slEtapa)
MERGE (Lectura)-[:HAS_SLOT {type:'enum',       cardinality:'1',   required:true, enum:['TemperaturaBaja','TemperaturaAlta','TemperaturaEnRango']}]->(slEstado)

// Corrida
MERGE (Corrida)-[:HAS_SLOT {type:'string',       cardinality:'1',   required:true}]->(slName)
// MERGE (Corrida)-[:HAS_SLOT {type:'integer',      cardinality:'1',   required:true}]->(slId)
MERGE (Corrida)-[:HAS_SLOT {type:'date',         cardinality:'0..1', required:true}]->(slFechaInicio)
MERGE (Corrida)-[:HAS_SLOT {type:'Etapa',        cardinality:'1',   required:true}]->(slEtapaActual)
MERGE (Corrida)-[:HAS_SLOT {type:'date',         cardinality:'0..1', required:false}]->(slFechaFin)
MERGE (Corrida)-[:HAS_SLOT {type:'list[Recomendacion]', cardinality:'0..N', required:false}]->(slRecomendaciones)
MERGE (Corrida)-[:HAS_SLOT {type:'list[Alerta]',        cardinality:'0..N', required:false}]->(slAlertas)
MERGE (Corrida)-[:HAS_SLOT {type:'list[Actuador]',      cardinality:'0..N', required:false}]->(slActuadores)
MERGE (Corrida)-[:HAS_SLOT {type:'Lectura',     cardinality:'1',   required:true}]->(slUltimaLectura)

// Alerta
MERGE (Alerta)-[:HAS_SLOT {type:'string',   cardinality:'1', required:true}]->(slName)
MERGE (Alerta)-[:HAS_SLOT {type:'datetime', cardinality:'1', required:true}]->(slTs)
MERGE (Alerta)-[:HAS_SLOT {type:'boolean',  cardinality:'1', required:true}]->(slActiva)
MERGE (Alerta)-[:HAS_SLOT {type:'string',   cardinality:'1', required:true}]->(slExplicacion)

// Recomendacion
MERGE (Recomendacion)-[:HAS_SLOT {type:'string',   cardinality:'1', required:true}]->(slName)
// MERGE (Recomendacion)-[:HAS_SLOT {type:'datetime', cardinality:'1', required:true}]->(slTs)
// MERGE (Recomendacion)-[:HAS_SLOT {type:'boolean',  cardinality:'1', required:true}]->(slActiva)
MERGE (Recomendacion)-[:HAS_SLOT {type:'integer',  cardinality:'1', required:true}]->(slPrioridad)
MERGE (Recomendacion)-[:HAS_SLOT {type:'list[Recomendacion]', cardinality:'0..N', required:true}]->(slConflictaCon)

// ===================== Clases derivadas simples (tipos específicos) =====================
// PuertaAbierta e Incendio (frames typeof Alerta). Se modelan como clases específicas.
MERGE (PuertaAbierta:FrameClass {name:'PuertaAbierta'})
MERGE (Incendio:FrameClass {name:'Incendio'})
MERGE (PuertaAbierta)-[:SUBCLASS_OF]->(Alerta)
MERGE (Incendio)-[:SUBCLASS_OF]->(Alerta)

// ===================== Instancias (FrameInstance) =====================
// Rangos (Temp80 / Temp30)
MERGE (temp80:FrameInstance:Rango {id:'temp_80'})-[:INSTANCE_OF]->(Rango)
MERGE (temp80)-[:HAS_VALUE {slot:'name',           value:'Rango de temperatura para proceso térmico', ts:datetime()}]->(slName)
MERGE (temp80)-[:HAS_VALUE {slot:'valorEsperado',  value:80.0, ts:datetime()}]->(slValorEsperado)
MERGE (temp80)-[:HAS_VALUE {slot:'tolerancia',     value:3.0,  ts:datetime()}]->(slTolerancia)
// MERGE (temp80)-[:HAS_VALUE {slot:'minimo',         value:77.0, ts:datetime()}]->(slMinimo)
// MERGE (temp80)-[:HAS_VALUE {slot:'maximo',         value:83.0, ts:datetime()}]->(slMaximo)

MERGE (temp30:FrameInstance:Rango {id:'temp_30'})-[:INSTANCE_OF]->(Rango)
MERGE (temp30)-[:HAS_VALUE {slot:'name',           value:'Rango de temperatura para enfriamiento', ts:datetime()}]->(slName)
MERGE (temp30)-[:HAS_VALUE {slot:'valorEsperado',  value:30.0, ts:datetime()}]->(slValorEsperado)
MERGE (temp30)-[:HAS_VALUE {slot:'tolerancia',     value:3.0,  ts:datetime()}]->(slTolerancia)
// MERGE (temp30)-[:HAS_VALUE {slot:'minimo',         value:27.0, ts:datetime()}]->(slMinimo)
// MERGE (temp30)-[:HAS_VALUE {slot:'maximo',         value:33.0, ts:datetime()}]->(slMaximo)

// Etapas (ProcesoTérmico / Enfriamiento)
MERGE (enf:FrameInstance:Etapa {id:'enfriamiento'})-[:INSTANCE_OF]->(Etapa)
MERGE (enf)-[:HAS_VALUE {slot:'name', value:'Enfriamiento', ts:datetime()}]->(slName)
MERGE (enf)-[:HAS_VALUE {slot:'configuracionTemperatura', value:'temp_30', ts:datetime()}]->(slConfigTemp)
MERGE (enf)-[:CONFIGURACION_TEMPERATURA {slot:'configuracionTemperatura', ts:datetime()}]->(temp30)

MERGE (procT:FrameInstance:Etapa {id:'proceso_termico'})-[:INSTANCE_OF]->(Etapa)
MERGE (procT)-[:HAS_VALUE {slot:'name', value:'Proceso Térmico', ts:datetime()}]->(slName)
MERGE (procT)-[:HAS_VALUE {slot:'configuracionTemperatura', value:'temp_80', ts:datetime()}]->(slConfigTemp)
MERGE (procT)-[:CONFIGURACION_TEMPERATURA {slot:'configuracionTemperatura', ts:datetime()}]->(temp80)
MERGE (procT)-[:HAS_VALUE {slot:'precedeA', value:'enfriamiento', ts:datetime()}]->(slPrecedeA)
MERGE (procT)-[:PRECEDE_A {slot:'precedeA', ts:datetime()}]->(enf)

MERGE (Corrida)-[:INICIA_EN {slot: 'etapaActual'}]-(procT)

// Actuadores (Calefactor / Ventilador)
MERGE (cal:FrameInstance:Actuador {id:'calefactor'})-[:INSTANCE_OF]->(Actuador)
MERGE (cal)-[:HAS_VALUE {slot:'name',     value:'Calefactor', ts:datetime()}]->(slName)
MERGE (cal)-[:HAS_VALUE {slot:'capacidad',value:1.0,          ts:datetime()}]->(slCapacidad)
MERGE (cal)-[:HAS_VALUE {slot:'activo',   value:false,        ts:datetime()}]->(slActivo)

MERGE (ven:FrameInstance:Actuador {id:'ventilador'})-[:INSTANCE_OF]->(Actuador)
MERGE (ven)-[:HAS_VALUE {slot:'name',     value:'Ventilador', ts:datetime()}]->(slName)
MERGE (ven)-[:HAS_VALUE {slot:'capacidad',value:-0.5,         ts:datetime()}]->(slCapacidad)
MERGE (ven)-[:HAS_VALUE {slot:'activo',   value:false,        ts:datetime()}]->(slActivo)

// Recomendaciones (instancias) + conflictos
MERGE (recEV:FrameInstance:Recomendacion {id:'encender_ventilador'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recEV)-[:HAS_VALUE {slot:'name',      value:'EncenderVentilador', ts:datetime()}]->(slName)
MERGE (recEV)-[:HAS_VALUE {slot:'prioridad', value:9, ts:datetime()}]->(slPrioridad)


MERGE (recAV:FrameInstance:Recomendacion {id:'apagar_ventilador'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recAV)-[:HAS_VALUE {slot:'name',      value:'ApagarVentilador', ts:datetime()}]->(slName)
MERGE (recAV)-[:HAS_VALUE {slot:'prioridad', value:8, ts:datetime()}]->(slPrioridad)


MERGE (recEC:FrameInstance:Recomendacion {id:'encender_calefactor'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recEC)-[:HAS_VALUE {slot:'name',      value:'EncenderCalefactor', ts:datetime()}]->(slName)
MERGE (recEC)-[:HAS_VALUE {slot:'prioridad', value:9, ts:datetime()}]->(slPrioridad)


MERGE (recAC:FrameInstance:Recomendacion {id:'apagar_calefactor'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recAC)-[:HAS_VALUE {slot:'name',      value:'ApagarCalefactor', ts:datetime()}]->(slName)
MERGE (recAC)-[:HAS_VALUE {slot:'prioridad', value:10, ts:datetime()}]->(slPrioridad)

MERGE (recM:FrameInstance:Recomendacion {id:'mantener_estado_actual'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recM)-[:HAS_VALUE {slot:'name',      value:'MantenerEstadoActual', ts:datetime()}]->(slName)
MERGE (recM)-[:HAS_VALUE {slot:'prioridad', value:1, ts:datetime()}]->(slPrioridad)


// Conflictos entre recomendaciones
MERGE (recEV)-[:CONFLICTA_CON]->(recAV)
MERGE (recEV)-[:CONFLICTA_CON]->(recM)

MERGE (recAV)-[:CONFLICTA_CON]->(recEV)
MERGE (recAV)-[:CONFLICTA_CON]->(recM)

MERGE (recEC)-[:CONFLICTA_CON]->(recAC)
MERGE (recEC)-[:CONFLICTA_CON]->(recM)

MERGE (recAC)-[:CONFLICTA_CON]->(recEC)
MERGE (recAC)-[:CONFLICTA_CON]->(recM)

MERGE (recM)-[:CONFLICTA_CON]->(recEV)
MERGE (recM)-[:CONFLICTA_CON]->(recAV)
MERGE (recM)-[:CONFLICTA_CON]->(recEC)
MERGE (recM)-[:CONFLICTA_CON]->(recAC)



// trigger para asegurar que solo haya una corrida activa (sin fechaFin)