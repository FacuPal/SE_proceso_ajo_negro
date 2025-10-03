// Esquema
CREATE CONSTRAINT frame_class_constraint IF NOT EXISTS FOR (c:FrameClass) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT frame_instance_constraint IF NOT EXISTS FOR (i:FrameInstance) REQUIRE i.id IS UNIQUE;
CREATE CONSTRAINT slot_constraint IF NOT EXISTS FOR (s:Slot) REQUIRE s.name IS UNIQUE;
CREATE CONSTRAINT slot_constraint IF NOT EXISTS FOR (s:Slot) REQUIRE s.name IS UNIQUE;
CREATE INDEX daemon_index IF NOT EXISTS FOR (d:Daemon) ON (d.name);
// Borrar triggers existentes (si los hay)
CALL apoc.trigger.removeAll();

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
MERGE (slActuadorActivo:Slot {name:'activo'})

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
MERGE (slExplicacion:Slot {name:'explicacion'})
MERGE (slActivo:Slot {name:'activo'})

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
MERGE (Actuador)-[:HAS_SLOT {type:'boolean', cardinality:'1', required:true}]->(slActuadorActivo)

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
MERGE (Alerta)-[:HAS_SLOT {type:'boolean',  cardinality:'1', required:true}]->(slActivo)
MERGE (Alerta)-[:HAS_SLOT {type:'string',   cardinality:'1', required:true}]->(slExplicacion)

// Recomendacion
MERGE (Recomendacion)-[:HAS_SLOT {type:'string',   cardinality:'1', required:true}]->(slName)
// MERGE (Recomendacion)-[:HAS_SLOT {type:'datetime', cardinality:'1', required:true}]->(slTs)
// MERGE (Recomendacion)-[:HAS_SLOT {type:'boolean',  cardinality:'1', required:true}]->(slActiva)
MERGE (Recomendacion)-[:HAS_SLOT {type:'integer',  cardinality:'1', required:true}]->(slPrioridad)
MERGE (Recomendacion)-[:HAS_SLOT {type:'list[Recomendacion]', cardinality:'0..N', required:false}]->(slConflictaCon)

// ===================== Clases derivadas simples (tipos específicos) =====================
// PuertaAbierta e Incendio (frames typeof Alerta). Se modelan como clases específicas.
MERGE (PuertaAbierta:FrameClass {name:'PuertaAbierta'})
MERGE (Incendio:FrameClass {name:'Incendio'})
MERGE (PuertaAbierta)-[:SUBCLASS_OF]->(Alerta)
MERGE (Incendio)-[:SUBCLASS_OF]->(Alerta)

// ===================== Defaults =====================
MERGE (Actuador)-[:DEFAULT {slot:'activo', value:false}]->(slActuadorActivo)

MERGE (Lectura)-[:DEFAULT {slot:'estado', value:'TemperaturaEnRango'}]->(slEstado)
MERGE (Lectura)-[:DEFAULT {slot:'ts', value:'datetime()'}]->(slTs)
MERGE (Lectura)-[:DEFAULT {slot:'tendencia', value:0.0}]->(slTendencia)

MERGE (Corrida)-[:DEFAULT {slot:'fechaInicio', value:'datetime()'}]->(slFechaInicio)
MERGE (Corrida)-[:DEFAULT {slot:'etapaActual', value:'proceso_termico'}]->(slEtapaActual)
MERGE (Corrida)-[:DEFAULT {slot:'actuadores', value:['calefactor', 'ventilador']}]->(slActuadores)

MERGE (Alerta)-[:DEFAULT {slot:'ts', value:'datetime()'}]->(slTs)
MERGE (Alerta)-[:DEFAULT {slot:'activo', value:true}]->(slActivo)

MERGE (PuertaAbierta)-[:DEFAULT {slot:'name', value:'PuertaAbierta'}]->(slName)

MERGE (Incendio)-[:DEFAULT {slot:'name', value:'Incendio'}]->(slName)

MERGE (Recomendacion)-[:DEFAULT {slot:'prioridad', value:1}]->(slPrioridad)

// ===================== Demonios =====================
MERGE (dActMinMax:Daemon {name:'actualizarMinimoMaximo'})
MERGE (dUpdEstadoActuador:Daemon {name:'actualizarEstadosActuadores'})
MERGE (dUpdTemp:Daemon {name:'actualizarTemperatura'})
MERGE (dUpdEstadoTemp:Daemon {name:'actualizarEstadoTemperatura'})
MERGE (dEvalAlertas:Daemon {name:'evaluarAlertas'})
MERGE (dEvalPrioridadRec:Daemon {name:'evaluarPrioridadRecomendaciones'})
MERGE (dEvalRecomendaciones:Daemon {name:'evaluarRecomendaciones'})

// Enlaces Slot -> Daemon
MERGE (slValorEsperado)-[ModificaValor:IF_MODIFIED]->(dActMinMax)
  ON CREATE SET ModificaValor.ts = datetime(), ModificaValor.source='seed'
  ON MATCH  SET ModificaValor.ts = datetime()

MERGE (slTolerancia)-[ModificaTolerancia:IF_MODIFIED]->(dActMinMax)
  ON CREATE SET ModificaTolerancia.ts = datetime(), ModificaTolerancia.source='seed'
  ON MATCH  SET ModificaTolerancia.ts = datetime()

MERGE (slActuadorActivo)-[ModificaActivoActuador:IF_NEEDED]->(dUpdEstadoActuador)
  ON CREATE SET ModificaActivoActuador.ts = datetime(), ModificaActivoActuador.source='seed'
  ON MATCH  SET ModificaActivoActuador.ts = datetime()

MERGE (slTempInt)-[ModificaTemp:IF_ADDED]->(dUpdTemp)
  ON CREATE SET ModificaTemp.ts = datetime(), ModificaTemp.source='seed'
  ON MATCH  SET ModificaTemp.ts = datetime()

MERGE (slTempInt)-[AgregaValor:IF_ADDED]->(dUpdEstadoTemp)
  ON CREATE SET AgregaValor.ts = datetime(), AgregaValor.source='seed'
  ON MATCH  SET AgregaValor.ts = datetime()

MERGE (slUltimaLectura)-[AgregaTendenciaAct:IF_ADDED]->(dUpdEstadoActuador)
  ON CREATE SET AgregaTendenciaAct.ts = datetime(), AgregaTendenciaAct.source='seed'
  ON MATCH  SET AgregaTendenciaAct.ts = datetime()

MERGE (slUltimaLectura)-[AgregaTendenciaPA:IF_ADDED]->(dEvalAlertas)
  ON CREATE SET AgregaTendenciaPA.ts = datetime(), AgregaTendenciaPA.source='seed'
  ON MATCH  SET AgregaTendenciaPA.ts = datetime()

MERGE (slUltimaLectura)-[ModificaUltimaLectura:IF_MODIFIED]->(dEvalRecomendaciones)
  ON CREATE SET ModificaUltimaLectura.ts = datetime(), ModificaUltimaLectura.source='seed'
  ON MATCH  SET ModificaUltimaLectura.ts = datetime()

MERGE (slRecomendaciones)-[ModificaRecs:IF_MODIFIED]->(dEvalPrioridadRec)
  ON CREATE SET ModificaRecs.ts = datetime(), ModificaRecs.source='seed'
  ON MATCH  SET ModificaRecs.ts = datetime()


MERGE (dActMinMax)-[:UPDATES]->(slMaximo)
MERGE (dActMinMax)-[:UPDATES]->(slMinimo)
MERGE (dUpdEstadoActuador)-[:UPDATES]->(slActuadorActivo)
MERGE (dUpdTemp)-[:UPDATES]->(slUltimaLectura)
MERGE (dUpdEstadoTemp)-[:UPDATES]->(slEstado)
MERGE (dEvalAlertas)-[:UPDATES]->(slAlertas)
MERGE (dEvalPrioridadRec)-[:UPDATES]->(slRecomendaciones)
MERGE (dEvalRecomendaciones)-[:UPDATES]->(slRecomendaciones)

// ===================== Instancias (FrameInstance) =====================
// Rangos (Temp80 / Temp30)
MERGE (temp80:FrameInstance:Rango {id:'temp_80'})-[:INSTANCE_OF]->(Rango)
MERGE (temp80)-[:HAS_VALUE {slot:'name',           value:'Rango de temperatura para proceso térmico', ts:datetime()}]->(slName)
MERGE (temp80)-[:HAS_VALUE {slot:'valorEsperado',  value:80.0, ts:datetime()}]->(slValorEsperado)
MERGE (temp80)-[:HAS_VALUE {slot:'tolerancia',     value:3.0,  ts:datetime()}]->(slTolerancia)
MERGE (temp80)-[:HAS_VALUE {slot:'minimo',         value:77.0, ts:datetime()}]->(slMinimo)
MERGE (temp80)-[:HAS_VALUE {slot:'maximo',         value:83.0, ts:datetime()}]->(slMaximo)

MERGE (temp30:FrameInstance:Rango {id:'temp_30'})-[:INSTANCE_OF]->(Rango)
MERGE (temp30)-[:HAS_VALUE {slot:'name',           value:'Rango de temperatura para enfriamiento', ts:datetime()}]->(slName)
MERGE (temp30)-[:HAS_VALUE {slot:'valorEsperado',  value:30.0, ts:datetime()}]->(slValorEsperado)
MERGE (temp30)-[:HAS_VALUE {slot:'tolerancia',     value:3.0,  ts:datetime()}]->(slTolerancia)
MERGE (temp30)-[:HAS_VALUE {slot:'minimo',         value:27.0, ts:datetime()}]->(slMinimo)
MERGE (temp30)-[:HAS_VALUE {slot:'maximo',         value:33.0, ts:datetime()}]->(slMaximo)

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
MERGE (cal)-[:HAS_VALUE {slot:'activo',   value:false,        ts:datetime()}]->(slActuadorActivo)

MERGE (ven:FrameInstance:Actuador {id:'ventilador'})-[:INSTANCE_OF]->(Actuador)
MERGE (ven)-[:HAS_VALUE {slot:'name',     value:'Ventilador', ts:datetime()}]->(slName)
MERGE (ven)-[:HAS_VALUE {slot:'capacidad',value:-0.5,         ts:datetime()}]->(slCapacidad)
MERGE (ven)-[:HAS_VALUE {slot:'activo',   value:false,        ts:datetime()}]->(slActuadorActivo)

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
MERGE (recM)-[:CONFLICTA_CON]->(recAC);

// ===================== Triggers =====================
// trigger para asegurar que solo haya una corrida activa (sin fechaFin)
CALL apoc.trigger.add('unaCorridaActiva',
  "
    UNWIND coalesce($createdNodes, []) AS node
    WITH node
    WHERE node:Corrida AND NOT (node)-[:HAS_VALUE {slot:'fechaFin'}]->(:Slot)

    // Buscar otras corridas activas (sin fechaFin) distintas a la creada
    MATCH (other:Corrida)
    WHERE other <> node AND NOT (other)-[:HAS_VALUE {slot:'fechaFin'}]->(:Slot)

    // Devolver un error si se encuentra alguna
    WITH collect(other) AS otrasCorridas
    CALL apoc.util.validate(size(otrasCorridas) > 0, 'Error: Solo puede haber una Corrida activa (sin fechaFin).', [])
    RETURN count(otrasCorridas) AS numOtrasCorridas
    ", {phase:'before'});

// MERGE (dActMinMax:Daemon {name:'actualizarMinimoMaximo'})
// Trigger para actualizar minimo y maximo al cambiar VE o Tol en un Rango
CALL apoc.trigger.add('actualizarMinimoMaximo',
  "
    // Obtenemos los cambios en las relaciones verificando la existencia de los cambios
    UNWIND coalesce($assignedRelationshipProperties.value, {}) AS chg
    WITH chg
    WHERE chg IS NOT NULL 
    UNWIND coalesce(chg, {}) AS chgRel
    //
    WITH chgRel.relationship AS rel, chgRel.key AS key, coalesce(chgRel.old, 0) AS old, chgRel.new AS new
    WHERE new IS NOT NULL AND key = 'value' AND type(rel) = 'HAS_VALUE' AND rel.slot IN ['valorEsperado','tolerancia']
    // CALL apoc.log.info('actMinMax: rel=' + toString(id(rel)))
    // CALL apoc.log.info('actMinMax: key=' + toString(key))
    // CALL apoc.log.info('actMinMax: old=' + toString(old))
    // CALL apoc.log.info('actMinMax: new=' + toString(new))


    // Instancia de :Rango afectada
    WITH DISTINCT startNode(rel) AS rangoNode
    WHERE rangoNode:Rango

    // Leer valores actuales de VE y Tol (pueden haber cambiado ambos en la misma tx)
    OPTIONAL MATCH (rangoNode)-[ve:HAS_VALUE {slot:'valorEsperado'}]->(:Slot)
    OPTIONAL MATCH (rangoNode)-[to:HAS_VALUE {slot:'tolerancia'}]->(:Slot)
    WITH rangoNode,
        toFloat(coalesce(ve.value,0)) AS veVal,
        toFloat(coalesce(to.value,0)) AS tolVal,
        datetime() AS now

    WITH rangoNode,
        (veVal - tolVal) AS nuevoMin,
        (veVal + tolVal) AS nuevoMax, now

    // CALL apoc.log.info('nuevoMin: ' + toString(nuevoMin))
    // CALL apoc.log.info('nuevoMax: ' + toString(nuevoMax))

    // Upsert de minimo y maximo
    MATCH (sMin:Slot {name:'minimo'}), (sMax:Slot {name:'maximo'})
    MERGE (rangoNode)-[rmin:HAS_VALUE {slot:'minimo'}]->(sMin)
      ON CREATE SET rmin.value = nuevoMin, rmin.ts = now, rmin.source='trigger_actualizarMinimoMaximo'
      ON MATCH  SET rmin.value = nuevoMin, rmin.ts = now, rmin.source='trigger_actualizarMinimoMaximo'

    MERGE (rangoNode)-[rmax:HAS_VALUE {slot:'maximo'}]->(sMax)
      ON CREATE SET rmax.value = nuevoMax, rmax.ts = now, rmax.source='trigger_actualizarMinimoMaximo'
      ON MATCH  SET rmax.value = nuevoMax, rmax.ts = now, rmax.source='trigger_actualizarMinimoMaximo'

    RETURN count(*) AS updated

",{phase:'after'});


// Trgger para no permitir agregar Lecturas a una Corrida que ya está finalizada
CALL apoc.trigger.add('verificarCorridaActiva',
  "
    UNWIND coalesce($createdRelationships, []) AS newRel
    WITH newRel
    WHERE type(newRel) = 'DE_CORRIDA'
    WITH startNode(newRel) AS newLectura, endNode(newRel) AS corrida
    WHERE newLectura:Lectura AND corrida:Corrida

    OPTIONAL MATCH (corrida)-[valFechaFin:HAS_VALUE {slot:'fechaFin'}]->(:Slot)
    CALL apoc.util.validate(valFechaFin IS NOT NULL, 'Error: No se pueden agregar Lecturas a una Corrida que ya está finalizada.', [])
    ", {phase:'before'});



CALL apoc.trigger.add('actualizarTemperatura',
  "
    // Cuando se crea una nueva Lectura
    UNWIND coalesce($createdRelationships, []) AS newRel
    WITH newRel WHERE type(newRel) = 'DE_CORRIDA'

    WITH startNode(newRel) AS newLectura, endNode(newRel) AS corrida
    WHERE newLectura:Lectura AND corrida:Corrida

    // Timestamps
    MATCH (newLectura)-[valTs:HAS_VALUE {slot:'ts'}]->(:Slot)
    OPTIONAL MATCH (corrida)-[rUltLect:ULTIMA_LECTURA]->(ultimaLectura:Lectura)-[valUltTs:HAS_VALUE {slot:'ts'}]->(:Slot)

    WITH corrida, newLectura, valTs, valUltTs, datetime() AS now, rUltLect
    WHERE valUltTs.value IS NULL OR valTs.value > valUltTs.value

    WITH corrida, newLectura, now, rUltLect
    // CALL apoc.log.info('Creando relación entre la corrida y la nueva lectura...')

    MERGE (corrida)-[hval:HAS_VALUE {slot:'ultimaLectura'}]->(:Slot {name:'ultimaLectura'})
       ON CREATE SET hval.value = newLectura.id, hval.ts = now, hval.source='trigger_actualizarTemperatura'
       ON MATCH  SET hval.value = newLectura.id, hval.ts = now, hval.source='trigger_actualizarTemperatura'

    WITH corrida, newLectura, now, rUltLect
    CALL apoc.refactor.to(rUltLect, newLectura) YIELD output as relNew
      SET relNew.ts = now, relNew.source='trigger_actualizarTemperatura'

", {phase:'afterAsync'});

// MERGE (dUpdEstadoActuador:Daemon {name:'actualizarEstadosActuadores'})
CALL apoc.trigger.add('actualizarEstadosActuadores',
  "
    // Cuando se crea una nueva relación de tipo ULTIMA_LECTURA o se modifica su value
    UNWIND coalesce($assignedRelationshipProperties.value, {}) AS chg
    WITH chg
    WHERE chg IS NOT NULL
    UNWIND coalesce(chg, {}) AS chgRel

    WITH chgRel.relationship AS rel, chgRel.key AS key, chgRel.new AS new
    WHERE new IS NOT NULL AND key = 'value' AND type(rel) = 'ULTIMA_LECTURA' AND startNode(rel):Corrida

    // CALL apoc.log.info('actMinMax: rel=' + toString(id(rel)))
    // CALL apoc.log.info('actMinMax: key=' + toString(key))
    // CALL apoc.log.info('actMinMax: new=' + toString(new))
    
    // Obtenemos la corrida que cambió su última lectura
    WITH DISTINCT startNode(rel) AS corridaNode, rel
    WHERE corridaNode:Corrida
    
    // Obtenemos la lectura actual
    MATCH (corridaNode)-[:HAS_VALUE {slot:'ultimaLectura'}]->(slUltimaLectura)
    MATCH (lectura:Lectura {id: rel.value})
    
    // Obtenemos la tendencia de la lectura
    MATCH (lectura)-[tendRel:HAS_VALUE {slot:'tendencia'}]->(slTendencia:Slot)
    WITH corridaNode, toFloat(tendRel.value) AS tendencia, datetime() AS now
    
    // Obtenemos los actuadores
    MATCH (calefactor:Actuador {id:'calefactor'})
    MATCH (ventilador:Actuador {id:'ventilador'})
    MATCH (calefactor)-[capCalRel:HAS_VALUE {slot:'capacidad'}]->(slCapacidad)
    MATCH (ventilador)-[capVenRel:HAS_VALUE {slot:'capacidad'}]->(slCapacidad)
    
    WITH corridaNode, tendencia, now, calefactor, ventilador,
         toFloat(capCalRel.value) AS capacidadCalefactor,
         toFloat(capVenRel.value) AS capacidadVentilador
    
    // Determinamos los estados según las reglas
    WITH corridaNode, tendencia, now, calefactor, ventilador, capacidadCalefactor, capacidadVentilador,
         CASE 
           WHEN tendencia > 0 THEN true
           WHEN tendencia < 0 AND tendencia > capacidadVentilador THEN true
           ELSE false
         END AS estadoCalefactor,
         CASE
           WHEN tendencia > 0 AND tendencia < capacidadCalefactor THEN true
           WHEN tendencia < 0 THEN true
           ELSE false
         END AS estadoVentilador
    
    // Actualizamos el estado del calefactor
    MATCH (slActuadorActivo:Slot {name:'activo'})
    MERGE (calefactor)-[rCalActivo:HAS_VALUE {slot:'activo'}]->(slActuadorActivo)
      ON CREATE SET rCalActivo.value = estadoCalefactor, rCalActivo.ts = now, rCalActivo.source='trigger_actualizarEstadosActuadores'
      ON MATCH  SET rCalActivo.value = estadoCalefactor, rCalActivo.ts = now, rCalActivo.source='trigger_actualizarEstadosActuadores'
    
    // Actualizamos el estado del ventilador
    MERGE (ventilador)-[rVenActivo:HAS_VALUE {slot:'activo'}]->(slActuadorActivo)
      ON CREATE SET rVenActivo.value = estadoVentilador, rVenActivo.ts = now, rVenActivo.source='trigger_actualizarEstadosActuadores'
      ON MATCH  SET rVenActivo.value = estadoVentilador, rVenActivo.ts = now, rVenActivo.source='trigger_actualizarEstadosActuadores'
    
    RETURN count(*) AS updated

", {phase:'after'});

// MERGE (dUpdEstadoTemp:Daemon {name:'actualizarEstadoTemperatura'})
// MERGE (dEvalAlertas:Daemon {name:'evaluarAlertas'})
// MERGE (dEvalPrioridadRec:Daemon {name:'evaluarPrioridadRecomendaciones'})
// MERGE (dEvalRecomendaciones:Daemon {name:'evaluarRecomendaciones'})


