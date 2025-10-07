// =================== 'system' DB ===================
:use system;

// ==================== Procedures =====================
// Borrar procedimientos almacenados existentes (si los hay)
CALL apoc.custom.dropAll('neo4j');

// SP para actualizar el estado de la temperatura
CALL apoc.custom.installProcedure(
  'actualizarEstadoTemperatura(lecturaId :: STRING) :: VOID',
  "   
    MATCH (lectura:Lectura {id:$lecturaId})
    WHERE lectura:Lectura
    // Obtener la temperatura interna de la lectura
    MATCH (lectura)-[tempRel:HAS_VALUE {slot:'temperaturaInterna'}]->(:Slot)
    WITH lectura, toFloat(tempRel.value) AS tempInt

    // Obtener la etapa asociada a la lectura
    MATCH (lectura)-[etRel:HAS_VALUE {slot:'etapa'}]->(:Slot)
    WITH lectura, tempInt, etRel.value AS etapaId
    MATCH (etapa:Etapa {id:etapaId})
    WHERE etapa:Etapa

    // Obtener el rango de temperatura asociado a la etapa
    MATCH (etapa)-[rangoRel:HAS_VALUE {slot:'configuracionTemperatura'}]->(:Slot)
    WITH lectura, tempInt, rangoRel.value AS rangoId
    MATCH (rango:Rango {id:rangoId})
    WHERE rango:Rango

    // Obtener los valores de minimo y maximo del rango
    MATCH (rango)-[minRel:HAS_VALUE {slot:'minimo'}]->(:Slot)
    MATCH (rango)-[maxRel:HAS_VALUE {slot:'maximo'}]->(:Slot)
    WITH lectura, tempInt,
          toFloat(minRel.value) AS minTemp,
          toFloat(maxRel.value) AS maxTemp,
          datetime() AS now

    // Determinar el nuevo estado basado en la temperatura interna y el rango
    WITH lectura, tempInt, minTemp, maxTemp, now,
          CASE 
            WHEN tempInt <= minTemp THEN 'TemperaturaBaja'
            WHEN tempInt >= maxTemp THEN 'TemperaturaAlta'
            ELSE 'TemperaturaEnRango'
          END AS nuevoEstado

    // Actualizar o crear la relación HAS_VALUE para el estado
    MATCH (slEstado:Slot {name:'estado'})
    MERGE (lectura)-[estadoRel:HAS_VALUE {slot:'estado'}]->(slEstado)
      ON CREATE SET estadoRel.value = nuevoEstado, estadoRel.ts = now, estadoRel.source='proc_actualizarEstadoTemperatura'
      ON MATCH  SET estadoRel.value = nuevoEstado, estadoRel.ts = now, estadoRel.source='proc_actualizarEstadoTemperatura'  
  ",
  'neo4j',
  'write',
  'Actualiza el estado de la temperatura de una Lectura basada en su valor y el rango de la etapa asociada'
);

// SP para actualizar el estado de los actuadores
CALL apoc.custom.installProcedure(
  'actualizarEstadosActuadores(corridaId :: STRING) :: VOID',
  "
    // Obtenemos corrida actual
    // MATCH (corrida:Corrida)
    // OPTIONAL MATCH (corrida)-[r:HAS_VALUE {slot: 'fechaFin'}]->()
    // WHERE r IS NULL OR r.value IS NULL
    MATCH (corrida:Corrida {id:$corridaId})

    // Obtener la última lectura asociada a la corrida
    MATCH (corrida)-[ultRel:ULTIMA_LECTURA]->(lectura:Lectura)

    // Obtener la tendencia de la lectura
    MATCH (lectura)-[tendRel:HAS_VALUE {slot:'tendencia'}]->(:Slot)
    WITH corrida, toFloat(tendRel.value) AS tendencia, datetime() AS now

    // Obtener los actuadores asociados a la corrida
    MATCH (corrida)-[:TIENE_ACTUADOR]->(calefactor:Actuador {id:'calefactor'})
    MATCH (corrida)-[:TIENE_ACTUADOR]->(ventilador:Actuador {id:'ventilador'})

    // Obtener la capacidad de los actuadores
    MATCH (calefactor)-[capRelCal:HAS_VALUE {slot:'capacidad'}]->(:Slot)
    MATCH (ventilador)-[capRelVent:HAS_VALUE {slot:'capacidad'}]->(:Slot)

    // Determinar el nuevo estado del actuador basado en la tendencia y su capacidad
    WITH corrida, tendencia, now,
          calefactor, ventilador,
          toFloat(capRelCal.value)  AS capCal,
          toFloat(capRelVent.value) AS capVent

    // Calcular estados segun la logica dada
    WITH tendencia, now, calefactor, ventilador, capCal, capVent,
          CASE
            WHEN tendencia > 0 THEN true
            WHEN tendencia < 0 AND tendencia > capVent THEN true
            ELSE false
          END AS estadoCalefactor,
          CASE
            WHEN tendencia < 0 THEN true
            WHEN tendencia > 0 AND tendencia < capCal THEN true
            ELSE false
          END AS estadoVentilador

    UNWIND [
      {actuador: calefactor, nuevoEstado: estadoCalefactor},
      {actuador: ventilador, nuevoEstado: estadoVentilador}
    ] AS actData
    WITH now, actData.actuador AS actuador, actData.nuevoEstado AS nuevoEstado


    // Actualizar o crear la relación HAS_VALUE para el estado del actuador
    MATCH (slActivo:Slot {name:'activo'})
    MERGE (actuador)-[activoRel:HAS_VALUE {slot:'activo'}]->(slActivo)
      ON CREATE SET activoRel.value = nuevoEstado, activoRel.ts = now, activoRel.source='proc_actualizarEstadosActuadores'
      ON MATCH SET activoRel.value = nuevoEstado, activoRel.ts = now, activoRel.source='proc_actualizarEstadosActuadores'
  ",
  'neo4j',
  'write',
  'Actualiza el estado de los actuadores asociados a una Corrida basada en la tendencia de la última Lectura'
);

// SP para evaluar alertas
CALL apoc.custom.installProcedure(
  'actualizarAlertas(corridaId :: STRING) :: VOID',
  " 
    // Obtenemos corrida actual
    // MATCH (corrida:Corrida)
    // OPTIONAL MATCH (corrida)-[r:HAS_VALUE {slot: 'fechaFin'}]->()
    // WHERE r IS NULL OR r.value IS NULL
    MATCH (corrida:Corrida {id:$corridaId})

    // Obtenemos las alertas activas de la corrida
    OPTIONAL MATCH (corrida)-[:ALERTA]->(alerta:Alerta)-[:INSTANCE_OF]->(fc:FrameClass)
    WHERE EXISTS((alerta)-[:HAS_VALUE {slot: 'activo', value: true}]->())
    WITH corrida, collect(fc.name) AS alertasActivas

    // Obtener la última lectura asociada a la corrida
    MATCH (corrida)-[ultRel:ULTIMA_LECTURA]->(lectura:Lectura)
    WHERE lectura:Lectura

    // Obtenemos la tendencia de la lectura
    MATCH (lectura)-[tendRel:HAS_VALUE {slot:'tendencia'}]->(:Slot)

    // Obtenemos las clases de alerta
    MATCH (cIncendio:FrameClass {name:'Incendio'})
    MATCH (cPA:FrameClass {name:'PuertaAbierta'})

    // Obtenemos slots comunes
    MATCH (sName:Slot {name:'name'})
    MATCH (sExplicacion:Slot {name:'explicacion'})
    MATCH (sActivo:Slot {name:'activo'})
    MATCH (sTs:Slot {name:'ts'})

    MATCH (slAlertas:Slot {name:'alertas'})
    WITH corrida, tendRel.value AS tendencia, datetime() AS now, cIncendio, cPA, sName, sExplicacion, sActivo, sTs, slAlertas,alertasActivas

    // === ALERTA DE INCENDIO ===
    // Crear/activar si se cumple condición
    CALL {
      WITH corrida, tendencia, now, cIncendio, sName, sExplicacion, sActivo, sTs, slAlertas, alertasActivas    
      WITH corrida, tendencia, now, cIncendio, sName, sExplicacion, sActivo, sTs, slAlertas, alertasActivas
      WHERE tendencia > 30.0 AND NOT 'Incendio' IN alertasActivas

      MERGE (alertaInc:FrameInstance:Alerta {id: 'incendio_' + apoc.create.uuid()})
        ON CREATE SET alertaInc.ts = now, alertaInc.source='proc_actualizarAlertas'
        ON MATCH  SET alertaInc.ts = now, alertaInc.source='proc_actualizarAlertas'
      MERGE (alertaInc)-[:INSTANCE_OF]->(cIncendio)
      MERGE (corrida)-[:HAS_VALUE {slot:'alertas', value:alertaInc.id, ts:now, source:'proc_actualizarAlertas'}]->(slAlertas)
      MERGE (alertaInc)-[:HAS_VALUE {slot:'name', value:'Alerta de Incendio', ts:now, source:'proc_actualizarAlertas'}]->(sName)
      MERGE (alertaInc)-[:HAS_VALUE {slot:'explicacion', value:'La temperatura está subiendo bruscamente (' + toString(tendencia) + '°C/min). Hay un posible incendio.', ts:now, source:'proc_actualizarAlertas'}]->(sExplicacion)
      MERGE (alertaInc)-[:HAS_VALUE {slot:'activo', value:true, ts:now, source:'proc_actualizarAlertas'}]->(sActivo)
      MERGE (alertaInc)-[:HAS_VALUE {slot:'ts', value:now, ts:now, source:'proc_actualizarAlertas'}]->(sTs)
      MERGE (corrida)-[:ALERTA {slot: 'alertas', ts: now, source: 'proc_actualizarAlertas'}]->(alertaInc)
    }

    // Desactivar si ya no se cumple condición
    CALL {
      WITH corrida, tendencia, now, sActivo
      WITH corrida, tendencia, now, sActivo
      WHERE tendencia <= 30.0
      
      MATCH (corrida)-[rAlerta:ALERTA]->(alertaInc:Alerta)
      WHERE (alertaInc)-[:INSTANCE_OF]->(:FrameClass {name:'Incendio'})
      MATCH (alertaInc)-[:HAS_VALUE {slot:'activo', value:true}]->(sActivo)
      MERGE (alertaInc)-[rActivo:HAS_VALUE {slot:'activo'}]->(sActivo)
        ON CREATE SET rActivo.value = false, rActivo.ts = now, rActivo.source='proc_actualizarAlertas'
        ON MATCH  SET rActivo.value = false, rActivo.ts = now, rActivo.source='proc_actualizarAlertas'
      DELETE rAlerta
    }

    // === ALERTA DE PUERTA ABIERTA ===
    // Crear/activar si se cumple condición
    CALL {
      WITH corrida, tendencia, now, cPA, sName, sExplicacion, sActivo, sTs, slAlertas, alertasActivas
      WITH corrida, tendencia, now, cPA, sName, sExplicacion, sActivo, sTs, slAlertas, alertasActivas
      WHERE tendencia < -3.0 AND NOT 'PuertaAbierta' IN alertasActivas

      MERGE (alertaPA:FrameInstance:Alerta {id: 'puerta_abierta_' + apoc.create.uuid()})
        ON CREATE SET alertaPA.ts = now, alertaPA.source='proc_actualizarAlertas'
        ON MATCH  SET alertaPA.ts = now, alertaPA.source='proc_actualizarAlertas'
      MERGE (alertaPA)-[:INSTANCE_OF]->(cPA)
      MERGE (corrida)-[:HAS_VALUE {slot:'alertas', value:alertaPA.id, ts:now, source:'proc_actualizarAlertas'}]->(slAlertas)
      MERGE (alertaPA)-[:HAS_VALUE {slot:'name', value:'Alerta de Puerta Abierta', ts:now, source:'proc_actualizarAlertas'}]->(sName)
      MERGE (alertaPA)-[:HAS_VALUE {slot:'explicacion', value:'La temperatura está bajando bruscamente (' + toString(tendencia) + '°C/min). Posiblemente la puerta está abierta.', ts:now, source:'proc_actualizarAlertas'}]->(sExplicacion)
      MERGE (alertaPA)-[:HAS_VALUE {slot:'activo', value:true, ts:now, source:'proc_actualizarAlertas'}]->(sActivo)
      MERGE (alertaPA)-[:HAS_VALUE {slot:'ts', value:now, ts:now, source:'proc_actualizarAlertas'}]->(sTs)
      MERGE (corrida)-[:ALERTA {slot: 'alertas', ts: now, source: 'proc_actualizarAlertas'}]->(alertaPA)
    }

    // Desactivar si ya no se cumple condición
    CALL {
      WITH corrida, tendencia, now, sActivo
      WITH corrida, tendencia, now, sActivo
      WHERE tendencia >= -3.0

      MATCH (corrida)-[rAlerta:ALERTA]->(alertaPA:Alerta)
      WHERE (alertaPA)-[:INSTANCE_OF]->(:FrameClass {name:'PuertaAbierta'})
      MATCH (alertaPA)-[:HAS_VALUE {slot:'activo', value:true}]->(sActivo)
      MERGE (alertaPA)-[rActivo:HAS_VALUE {slot:'activo'}]->(sActivo)
        ON CREATE SET rActivo.value = false, rActivo.ts = now, rActivo.source='proc_actualizarAlertas'
        ON MATCH  SET rActivo.value = false, rActivo.ts = now, rActivo.source='proc_actualizarAlertas'
      DELETE rAlerta
    }

  ",
  'neo4j',
  'write',
  'Evalúa y crea las alertas asociadas a una Corrida'
);

// SP para evaluar recomendaciones
CALL apoc.custom.installProcedure(
  'actualizarRecomendaciones(corridaId :: STRING) :: VOID',
  "
    // Obtenemos corrida actual
    // MATCH (corrida:Corrida)
    // OPTIONAL MATCH (corrida)-[r:HAS_VALUE {slot: 'fechaFin'}]->()
    // WHERE r IS NULL OR r.value IS NULL
    MATCH (corrida:Corrida {id:$corridaId})
    
    // Quitamos todas las recomendaciones existentes
    OPTIONAL MATCH (corrida)-[rRecomendacion:RECOMIENDA]->(:Recomendacion)
    OPTIONAL MATCH (corrida)-[rHasRec:HAS_VALUE {slot:'recomendaciones'}]->(:Slot)
    DELETE rRecomendacion, rHasRec

    WITH corrida

    // Obtenemos los actuadores asociados a la corrida
    MATCH (corrida)-[:TIENE_ACTUADOR]->(calefactor:Actuador {id:'calefactor'})
    MATCH (calefactor)-[rCalefactorActivo:HAS_VALUE {slot:'activo'}]->(:Slot)
    MATCH (corrida)-[:TIENE_ACTUADOR]->(ventilador:Actuador {id:'ventilador'})
    MATCH (ventilador)-[rVentiladorActivo:HAS_VALUE {slot:'activo'}]->(:Slot)

    // Obtener la última lectura asociada a la corrida
    MATCH (corrida)-[ultRel:ULTIMA_LECTURA]->(lectura:Lectura)

    // Obtenemos slot recomendacion
    MATCH (sRecomendaciones:Slot {name:'recomendaciones'})

    // Obtenemos el estado de la temperatura 
    MATCH (lectura)-[estadoRel:HAS_VALUE {slot:'estado'}]->(:Slot)
    WITH corrida, calefactor, ventilador, estadoRel.value AS estadoTemp, datetime() AS now, 
         toBoolean(rCalefactorActivo.value) AS calefactorActivo,
         toBoolean(rVentiladorActivo.value) AS ventiladorActivo,
         sRecomendaciones
    
    // === REGLA_ENCENDER_VENTILADOR ===
    CALL {
      WITH corrida, estadoTemp, now, ventiladorActivo, sRecomendaciones           
      WITH corrida, estadoTemp, now, ventiladorActivo, sRecomendaciones            
      WHERE NOT ventiladorActivo AND estadoTemp = 'TemperaturaAlta'
      
      MATCH (reco:Recomendacion {id: 'encender_ventilador'}) 
      MERGE (corrida)-[:HAS_VALUE {slot:'recomendaciones', value:reco.id, ts:now, source:'proc_actualizarRecomendaciones'}]->(sRecomendaciones)
      MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(reco)
      ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
    }

    // === REGLA_APAGAR_VENTILADOR ===
    CALL {
      WITH corrida, estadoTemp, now, ventiladorActivo, sRecomendaciones
      WITH corrida, estadoTemp, now, ventiladorActivo, sRecomendaciones
      WHERE ventiladorActivo AND estadoTemp <> 'TemperaturaAlta'
      MATCH (reco:Recomendacion {id: 'apagar_ventilador'})
      MERGE (corrida)-[:HAS_VALUE {slot:'recomendaciones', value:reco.id, ts:now, source:'proc_actualizarRecomendaciones'}]->(sRecomendaciones)
      MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(reco)
      ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
    }

    // === REGLA_ENCENDER_CALECTOR ===
    CALL {
      WITH corrida, estadoTemp, now, calefactorActivo, sRecomendaciones           
      WITH corrida, estadoTemp, now, calefactorActivo, sRecomendaciones            
      WHERE NOT calefactorActivo AND estadoTemp = 'TemperaturaBaja'
      MATCH (reco:Recomendacion {id: 'encender_calefactor'}) 
      MERGE (corrida)-[:HAS_VALUE {slot:'recomendaciones', value:reco.id, ts:now, source:'proc_actualizarRecomendaciones'}]->(sRecomendaciones)
      MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(reco)
      ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
    }

    // === REGLA_APAGAR_CALECTOR ===
    CALL {
      WITH corrida, estadoTemp, now, calefactorActivo, sRecomendaciones
      WITH corrida, estadoTemp, now, calefactorActivo, sRecomendaciones
      WHERE calefactorActivo AND estadoTemp <> 'TemperaturaBaja'
      MATCH (reco:Recomendacion {id: 'apagar_calefactor'})
      MERGE (corrida)-[:HAS_VALUE {slot:'recomendaciones', value:reco.id, ts:now, source:'proc_actualizarRecomendaciones'}]->(sRecomendaciones)
      MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(reco)
      ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime() 
    }

    // == REGLA_MANTENER_ESTADO_ACTUAL ===
    CALL {
      WITH corrida, estadoTemp, now, calefactorActivo, ventiladorActivo, sRecomendaciones
      WITH corrida, estadoTemp, now, calefactorActivo, ventiladorActivo, sRecomendaciones
      WHERE estadoTemp = 'TemperaturaEnRango' 
      OR (estadoTemp = 'TemperaturaAlta' AND ventiladorActivo)
      OR (estadoTemp = 'TemperaturaBaja' AND calefactorActivo)
      MATCH (reco:Recomendacion {id: 'mantener_estado_actual'})
      MERGE (corrida)-[:HAS_VALUE {slot:'recomendaciones', value:reco.id, ts:now, source:'proc_actualizarRecomendaciones'}]->(sRecomendaciones)
      MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(reco)
      ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
    }

    // Ordenar por prioridad y quitar las recomendaciones conflictivas con menor prioridad
  ",
  'neo4j',
  'write',
  'Evalúa y crea las recomendaciones asociadas a una Corrida'
);

// SP para evaluar prioridad de recomendaciones
CALL apoc.custom.installProcedure(
  'evaluarPrioridadRecomendaciones(corridaId :: STRING) :: VOID',
  "
    // Obtenemos corrida actual
    MATCH (corrida:Corrida {id:$corridaId})

    // Recolectar recomendaciones con su prioridad y sus conflictos (relaciones CONFLICTA_CON)
    MATCH (corrida)-[:RECOMIENDA]->(reco:Recomendacion)
    MATCH (reco)-[rPrioridad:HAS_VALUE {slot:'prioridad'}]->(:Slot)
    OPTIONAL MATCH (reco)-[:CONFLICTA_CON]->(rc:Recomendacion)
    WITH corrida, reco, toInteger(rPrioridad.value) AS prioridad, collect(DISTINCT rc.id) AS conflictos
    ORDER BY prioridad DESC
    WITH corrida, collect({reco:reco, prioridad:prioridad, conflictos:conflictos}) AS recs

    // Reducir la lista manteniendo solo la recomendación de mayor prioridad por cada grupo de conflicto
    WITH corrida,
         reduce(sel = [], r IN recs |
           CASE
             WHEN ANY(x IN sel WHERE r.reco.id IN x.conflictos OR x.reco.id IN r.conflictos) THEN sel
             ELSE sel + r
           END
         ) AS aceptadas

    WITH corrida, [r IN aceptadas | r.reco] AS finalRecs
    MATCH (sRecomendaciones:Slot {name:'recomendaciones'})

    // Eliminar recomendaciones descartadas (relaciones RECOMIENDA)
    OPTIONAL MATCH (corrida)-[rOld:RECOMIENDA]->(oldReco:Recomendacion)
    WHERE NOT oldReco IN finalRecs
    DELETE rOld

    WITH corrida, finalRecs, sRecomendaciones
    // Eliminar HAS_VALUE obsoletos del slot 'recomendaciones'
    OPTIONAL MATCH (corrida)-[hvOld:HAS_VALUE {slot:'recomendaciones'}]->(sRecomendaciones)
    WHERE NOT hvOld.value IN [r IN finalRecs | r.id]
    DELETE hvOld

    WITH corrida, finalRecs, sRecomendaciones
    // Asegurar recomendaciones finales (RECOMIENDA + HAS_VALUE)
    UNWIND finalRecs AS finalReco
    MERGE (corrida)-[rNew:RECOMIENDA {slot:'recomendaciones'}]->(finalReco)
      ON CREATE SET rNew.source='proc_evaluarPrioridadRecomendaciones', rNew.ts=datetime()
      ON MATCH  SET rNew.source='proc_evaluarPrioridadRecomendaciones', rNew.ts=datetime()
    MERGE (corrida)-[hv:HAS_VALUE {slot:'recomendaciones', value:finalReco.id}]->(sRecomendaciones)
      ON CREATE SET hv.source='proc_evaluarPrioridadRecomendaciones', hv.ts=datetime()
      ON MATCH  SET hv.source='proc_evaluarPrioridadRecomendaciones', hv.ts=datetime()
  ",
  'neo4j',
  'write',  
  'Evalúa las recomendaciones de la corrida y las ajusta de acuerdo a la prioridad de cada recomendación.'
);



// ==================== 'neo4j' DB ===================
:use neo4j;

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
CALL apoc.util.sleep(2000); // Esperar a que se creen los índices y constraints
// Borrar triggers existentes (si los hay)
CALL apoc.trigger.removeAll();

// Trigger para agregar relacion no canonica ETAPA_ACTUAL desde Corrida a Etapa
CALL apoc.trigger.add('relacionarCorridaEtapa',
  "
    // Cuando se crea una nueva Lectura
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='etapaActual'
    WITH rel, startNode(rel) AS corrida, rel.value AS etapaId
    WHERE corrida:Corrida AND etapaId IS NOT NULL
    MATCH (etapa:Etapa {id:etapaId})
    MERGE (corrida)-[r:ETAPA_ACTUAL {slot:'etapa'}]->(etapa)
      ON CREATE SET r.source='trigger_relacionarCorridaEtapa', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaEtapa', r.ts=datetime()
    RETURN count(*) AS created
    ", {phase:'afterAsync'});

// Trigger para no permitir agregar Lecturas a una Corrida que ya está finalizada
CALL apoc.trigger.add('verificarCorridaActiva',
  "
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='corrida'
    WITH rel, startNode(rel) AS lectura, rel.value AS corridaId
    WHERE lectura:Lectura AND corridaId IS NOT NULL 
    MATCH (corrida:Corrida {id:corridaId})

    OPTIONAL MATCH (corrida)-[valFechaFin:HAS_VALUE {slot:'fechaFin'}]->(:Slot)
    CALL apoc.util.validate(valFechaFin IS NOT NULL, 'Error: No se pueden agregar Lecturas a una Corrida que ya está finalizada.', [])
    ", {phase:'before'});


// Trigger para agregar relacion no canonica DE_CORRIDA desde Lectura a Corrida
CALL apoc.trigger.add('relacionarLecturaCorrida',
  "
    // Cuando se crea una nueva Lectura
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='corrida'
    WITH rel, startNode(rel) AS lectura, rel.value AS corridaId
    WHERE lectura:Lectura AND corridaId IS NOT NULL 
    MATCH (corrida:Corrida {id:corridaId})
    MERGE (lectura)-[r:DE_CORRIDA {slot:'corrida'}]->(corrida)
      ON CREATE SET r.source='trigger_relacionarLecturaCorrida', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarLecturaCorrida', r.ts=datetime()
    RETURN count(*) AS created
    ", {phase:'afterAsync'});

// Trigger para agregar relacion no canonica EN_ETAPA desde Lectura a Etapa
CALL apoc.trigger.add('relacionarLecturaEtapa',
  "
    // Cuando se crea una nueva Lectura
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='etapa'
    WITH rel, startNode(rel) AS lectura, rel.value AS etapaId
    WHERE lectura:Lectura AND etapaId IS NOT NULL 
    MATCH (etapa:Etapa {id:etapaId})
    MERGE (lectura)-[r:EN_ETAPA {slot:'etapa'}]->(etapa)
      ON CREATE SET r.source='trigger_relacionarLecturaEtapa', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarLecturaEtapa', r.ts=datetime()
    RETURN count(*) AS created
    ", {phase:'afterAsync'});

// Trigger para agregar relacion no canonica TIENE_ACTUADOR desde Corrida a Actuador
CALL apoc.trigger.add('relacionarCorridaActuador',
  "
    // Cuando se crea una nueva relación HAS_VALUE para el slot 'actuadores' en Corrida
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='actuadores'
    WITH rel, startNode(rel) AS corrida, rel.value AS actuadorId
    WHERE corrida:Corrida AND actuadorId IS NOT NULL
    MATCH (actuador:Actuador {id:actuadorId})
    MERGE (corrida)-[r:TIENE_ACTUADOR {slot:'actuadores'}]->(actuador)
      ON CREATE SET r.source='trigger_relacionarCorridaActuador', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaActuador', r.ts=datetime()
    RETURN count(*) AS created
    ", {phase:'afterAsync'});

// Trigger para agregar relacion no canonica RECOMIENDA desde Corrida a Recomendacion
CALL apoc.trigger.add('relacionarCorridaRecomendacion',
  "
    // Cuando se crea una nueva relación HAS_VALUE para el slot 'recomendaciones' en Corrida
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='recomendaciones'
    WITH rel, startNode(rel) AS corrida, rel.value AS recomendacionId
    WHERE corrida:Corrida AND recomendacionId IS NOT NULL
    MATCH (recomendacion:Recomendacion {id:recomendacionId})
    MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(recomendacion)
      ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime()
    RETURN count(*) AS created
    ", {phase:'afterAsync'});

// Trigger para agregar relacion no canonica ALERTA desde Corrida a Alerta
CALL apoc.trigger.add('relacionarCorridaAlerta',
  "
    // Cuando se crea una nueva relación HAS_VALUE para el slot 'alertas' en Corrida
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='alertas'
    WITH rel, startNode(rel) AS corrida, rel.value AS alertaId
    WHERE corrida:Corrida AND alertaId IS NOT NULL
    MATCH (alerta:Alerta {id:alertaId})
    MERGE (corrida)-[r:ALERTA {slot:'alertas'}]->(alerta)
      ON CREATE SET r.source='trigger_relacionarCorridaAlerta', r.ts=datetime()
      ON MATCH  SET r.source='trigger_relacionarCorridaAlerta', r.ts=datetime()
    RETURN count(*) AS created
    ", {phase:'afterAsync'});


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

// Trigger para actualizar minimo y maximo al cambiar VE o Tol en un Rango
CALL apoc.trigger.add('actualizarMinimoMaximo',
  "
    // Obtenemos los cambios en las relaciones verificando la existencia de los cambios
    UNWIND coalesce($assignedRelationshipProperties.value, {}) AS chg
    WITH chg
    WHERE chg IS NOT NULL 
    UNWIND coalesce(chg, {}) AS chgRel
    WITH chgRel.relationship AS rel, chgRel.key AS key, coalesce(chgRel.old, 0) AS old, chgRel.new AS new
    WHERE new IS NOT NULL AND key = 'value' AND type(rel) = 'HAS_VALUE' AND rel.slot IN ['valorEsperado','tolerancia']


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

    // Upsert de minimo y maximo
    MATCH (sMin:Slot {name:'minimo'}), (sMax:Slot {name:'maximo'})
    MERGE (rangoNode)-[rmin:HAS_VALUE {slot:'minimo'}]->(sMin)
      ON CREATE SET rmin.value = nuevoMin, rmin.ts = now, rmin.source='trigger_actualizarMinimoMaximo'
      ON MATCH  SET rmin.value = nuevoMin, rmin.ts = now, rmin.source='trigger_actualizarMinimoMaximo'

    MERGE (rangoNode)-[rmax:HAS_VALUE {slot:'maximo'}]->(sMax)
      ON CREATE SET rmax.value = nuevoMax, rmax.ts = now, rmax.source='trigger_actualizarMinimoMaximo'
      ON MATCH  SET rmax.value = nuevoMax, rmax.ts = now, rmax.source='trigger_actualizarMinimoMaximo'

    RETURN count(*) AS updated

",{phase:'afterAsync'});


// WIP: Este hay que convertirlo en SP y llamarlo desde el trigger que crea la relación DE_CORRIDA
CALL apoc.trigger.add('actualizarTemperatura',
  "
    // Cuando se crea una nueva Lectura
    UNWIND coalesce($createdRelationships, []) AS rel
    WITH rel
    WHERE type(rel)='HAS_VALUE' AND rel.slot='corrida'
    WITH rel, startNode(rel) AS newLectura, rel.value AS corridaId
    WHERE newLectura:Lectura AND corridaId IS NOT NULL 
    MATCH (corrida:Corrida {id:corridaId})

    CALL apoc.log.info('Trigger actualizarTemperatura: Procesando nueva lectura ' + newLectura.id + ' para corrida ' + corridaId)

    WITH newLectura, corrida

    // Timestamps
    MATCH (newLectura)-[valTs:HAS_VALUE {slot:'ts'}]->(:Slot)
    OPTIONAL MATCH (corrida)-[rUltLect:ULTIMA_LECTURA]->(ultimaLectura:Lectura)
    OPTIONAL MATCH (ultimaLectura)-[valUltTs:HAS_VALUE {slot:'ts'}]->(:Slot)

    WITH corrida, newLectura, valTs, valUltTs, datetime() AS now, rUltLect, ultimaLectura
    WHERE ultimaLectura IS NULL OR valUltTs.value IS NULL OR valTs.value > valUltTs.value

    WITH corrida, newLectura, now, rUltLect
    MATCH (sUltimaLectura:Slot {name:'ultimaLectura'})
    MERGE (corrida)-[hval:HAS_VALUE {slot:'ultimaLectura'}]->(sUltimaLectura)
      ON CREATE SET hval.value = newLectura.id, hval.ts = now, hval.source='trigger_actualizarTemperatura'
      ON MATCH  SET hval.value = newLectura.id, hval.ts = now, hval.source='trigger_actualizarTemperatura'

    // Borramos las relaciones ULTIMA_LECTURA existentes y creamos la nueva
    WITH corrida, newLectura, now
    OPTIONAL MATCH (corrida)-[rUltLectOld:ULTIMA_LECTURA]->()
    DELETE rUltLectOld
    
    MERGE (corrida)-[rUltLect:ULTIMA_LECTURA {slot:'ultimaLectura'}]->(newLectura)
      ON CREATE SET rUltLect.slot = 'ultimaLectura', rUltLect.ts = now, rUltLect.source='trigger_actualizarTemperatura'
      ON MATCH  SET rUltLect.slot = 'ultimaLectura', rUltLect.ts = now, rUltLect.source='trigger_actualizarTemperatura'

    WITH newLectura, corrida
    // Llamar al SP para actualizar el estado de la temperatura
    CALL apoc.log.info('Trigger actualizarTemperatura: Llamando al SP para actualizar el estado de la temperatura.')
    CALL custom.actualizarEstadoTemperatura(newLectura.id)
    
    // Llamar al SP para actualizar el estado de los actuadores
    CALL apoc.log.info('Trigger actualizarTemperatura: Llamando al SP para actualizar el estado de los actuadores.')
    CALL custom.actualizarEstadosActuadores(corrida.id)

    // Llamar al SP para evaluar alertas 
    CALL apoc.log.info('Trigger actualizarTemperatura: Llamando al SP para evaluar alertas.')
    CALL custom.actualizarAlertas(corrida.id)

    // Llamar al SP para evaluar recomendaciones
    CALL apoc.log.info('Trigger actualizarTemperatura: Llamando al SP para evaluar recomendaciones.')
    CALL custom.actualizarRecomendaciones(corrida.id)

", {phase:'afterAsync'});

// // MERGE (dEvalPrioridadRec:Daemon {name:'evaluarPrioridadRecomendaciones'})