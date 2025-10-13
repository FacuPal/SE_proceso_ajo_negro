// =================== 'system' DB ===================
:use system;

// TODO: agregar fuzzy logic en los triggers y procedimientos

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

    MATCH (rango)-[rTipoFuncionBaja:HAS_VALUE {slot:'tipoFuncionBaja'}]->(:Slot)
    MATCH (rango)-[rBajaB:HAS_VALUE {slot:'bajaB'}]->(:Slot)
    MATCH (rango)-[rBajaC:HAS_VALUE {slot:'bajaC'}]->(:Slot)
    MATCH (rango)-[rTipoFuncionEnRango:HAS_VALUE {slot:'tipoFuncionEnRango'}]->(:Slot)
    MATCH (rango)-[rEnRangoMedia:HAS_VALUE {slot:'enRangoMedia'}]->(:Slot)
    MATCH (rango)-[rEnRangoSigma:HAS_VALUE {slot:'enRangoSigma'}]->(:Slot)
    MATCH (rango)-[rTipoFuncionAlta:HAS_VALUE {slot:'tipoFuncionAlta'}]->(:Slot)
    MATCH (rango)-[rAltaB:HAS_VALUE {slot:'altaB'}]->(:Slot)
    MATCH (rango)-[rAltaC:HAS_VALUE {slot:'altaC'}]->(:Slot)
    WITH lectura, tempInt, rango,
          rTipoFuncionBaja.value AS funcionBaja,
          toFloat(rBajaB.value) AS bajaB,
          toFloat(rBajaC.value) AS bajaC,
          rTipoFuncionEnRango.value AS funcionEnRango,
          toFloat(rEnRangoMedia.value) AS enRangoMedia,
          toFloat(rEnRangoSigma.value) AS enRangoSigma,
          rTipoFuncionAlta.value AS funcionAlta,
          toFloat(rAltaB.value) AS altaB,
          toFloat(rAltaC.value) AS altaC,
          datetime() AS now


    // Determinar el nuevo estado basado en la temperatura interna y el rango
    WITH  lectura, tempInt, now,
          1 / (1 + exp(-(bajaC) * (tempInt - bajaB))) AS mu_baja,
          exp(-((tempInt - enRangoMedia)^2) / (2 * (enRangoSigma^2))) AS mu_en_rango,
          1 / (1 + exp(-altaC * (tempInt - altaB))) AS mu_alta


    // Actualizar los valores de pertenencia en la lectura
    MATCH (slUAlta:Slot {name:'uAlta'})
    MATCH (slUBaja:Slot {name:'uBaja'})
    MATCH (slUEnRango:Slot {name:'uEnRango'})
    MERGE (lectura)-[uAltaRel:HAS_VALUE {slot:'uAlta'}]->(slUAlta)
      ON CREATE SET uAltaRel.value = round(mu_alta, 4), uAltaRel.ts = now, uAltaRel.source='proc_actualizarEstadoTemperatura'
      ON MATCH  SET uAltaRel.value = round(mu_alta, 4), uAltaRel.ts = now, uAltaRel.source='proc_actualizarEstadoTemperatura'
    MERGE (lectura)-[uBajaRel:HAS_VALUE {slot:'uBaja'}]->(slUBaja)
      ON CREATE SET uBajaRel.value = round(mu_baja, 4), uBajaRel.ts = now, uBajaRel.source='proc_actualizarEstadoTemperatura'
      ON MATCH  SET uBajaRel.value = round(mu_baja, 4), uBajaRel.ts = now, uBajaRel.source='proc_actualizarEstadoTemperatura'
    MERGE (lectura)-[uEnRangoRel:HAS_VALUE {slot:'uEnRango'}]->(slUEnRango)
      ON CREATE SET uEnRangoRel.value = round(mu_en_rango, 4), uEnRangoRel.ts = now, uEnRangoRel.source='proc_actualizarEstadoTemperatura'
      ON MATCH  SET uEnRangoRel.value = round(mu_en_rango, 4), uEnRangoRel.ts = now, uEnRangoRel.source='proc_actualizarEstadoTemperatura'
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

    // Actualizamos estado calefactor
    // TODO: Probablemente cambiar la función de prendido por una sigmoide?
    CALL {
      WITH corrida, tendencia, now
      MATCH (corrida)-[:TIENE_ACTUADOR]->(calefactor:Actuador {id:'calefactor'})

        // Obtener la capacidad del calefactor
      MATCH (calefactor)-[capRelCal:HAS_VALUE {slot:'capacidad'}]->(:Slot)

      // Obtenemos los slots del calefactor
      MATCH (calefactor)-[rTipoFuncionPrendido:HAS_VALUE {slot:'tipoFuncionPrendido'}]->(:Slot)
      MATCH (calefactor)-[rPrendidoMedia:HAS_VALUE {slot:'prendidoMedia'}]->(:Slot)
      MATCH (calefactor)-[rPrendidoSigma:HAS_VALUE {slot:'prendidoSigma'}]->(:Slot)
      MATCH (calefactor)-[rTipoFuncionApagado:HAS_VALUE {slot:'tipoFuncionApagado'}]->(s:Slot)
      MATCH (calefactor)-[rApagadoB:HAS_VALUE {slot:'apagadoB'}]->(:Slot)
      MATCH (calefactor)-[rApagadoC:HAS_VALUE {slot:'apagadoC'}]->(:Slot)

      WITH corrida, tendencia, now, calefactor, toFloat(capRelCal.value) AS capCal,
          rTipoFuncionPrendido.value AS funcionPrendidoCal,
          toFloat(rPrendidoMedia.value) AS prendidoMediaCal,
          toFloat(rPrendidoSigma.value) AS prendidoSigmaCal,
          rTipoFuncionApagado.value AS funcionApagadoCal,
          toFloat(rApagadoB.value) AS apagadoBCal,
          toFloat(rApagadoC.value) AS apagadoCCal

      // Determinar el nuevo estado basado en la tendencia
      WITH corrida, tendencia, now, calefactor, capCal,
            1 / (1 + exp(-(apagadoCCal) * (tendencia - apagadoBCal))) AS mu_apagado,
            exp(-((tendencia - prendidoMediaCal)^2) / (2 * (prendidoSigmaCal^2))) AS mu_prendido

      // Actualizar los valores de pertenencia en el calefactor
      MATCH (slUPrendido:Slot {name:'uPrendido'})
      MATCH (slUApagado:Slot {name:'uApagado'})
      MERGE (calefactor)-[uPrendidoRel:HAS_VALUE {slot:'uPrendido'}]->(slUPrendido)
        ON CREATE SET uPrendidoRel.value = round(mu_prendido, 4), uPrendidoRel.ts = now, uPrendidoRel.source='proc_actualizarEstadosActuadores'
        ON MATCH  SET uPrendidoRel.value = round(mu_prendido, 4), uPrendidoRel.ts = now, uPrendidoRel.source='proc_actualizarEstadosActuadores'
      MERGE (calefactor)-[uApagadoRel:HAS_VALUE {slot:'uApagado'}]->(slUApagado)
        ON CREATE SET uApagadoRel.value = round(mu_apagado, 4), uApagadoRel.ts = now, uApagadoRel.source='proc_actualizarEstadosActuadores'
        ON MATCH  SET uApagadoRel.value = round(mu_apagado, 4), uApagadoRel.ts = now, uApagadoRel.source='proc_actualizarEstadosActuadores'
    }

    // Actualizamos estado ventilador
    CALL {
      WITH corrida, tendencia, now
      MATCH (corrida)-[:TIENE_ACTUADOR]->(ventilador:Actuador {id:'ventilador'})

        // Obtener la capacidad del ventilador
      MATCH (ventilador)-[capRelVent:HAS_VALUE {slot:'capacidad'}]->(:Slot)

      // Obtenemos los slots del ventilador
      MATCH (ventilador)-[rTipoFuncionPrendido:HAS_VALUE {slot:'tipoFuncionPrendido'}]->(:Slot)
      MATCH (ventilador)-[rPrendidoMedia:HAS_VALUE {slot:'prendidoMedia'}]->(:Slot)
      MATCH (ventilador)-[rPrendidoSigma:HAS_VALUE {slot:'prendidoSigma'}]->(:Slot)
      MATCH (ventilador)-[rTipoFuncionApagado:HAS_VALUE {slot:'tipoFuncionApagado'}]->(s:Slot)
      MATCH (ventilador)-[rApagadoB:HAS_VALUE {slot:'apagadoB'}]->(:Slot)
      MATCH (ventilador)-[rApagadoC:HAS_VALUE {slot:'apagadoC'}]->(:Slot)

      WITH corrida, tendencia, now, ventilador, toFloat(capRelVent.value) AS capVent,
          rTipoFuncionPrendido.value AS funcionPrendidoVent,
          toFloat(rPrendidoMedia.value) AS prendidoMediaVent,
          toFloat(rPrendidoSigma.value) AS prendidoSigmaVent,
          rTipoFuncionApagado.value AS funcionApagadoVent,
          toFloat(rApagadoB.value) AS apagadoBVent,
          toFloat(rApagadoC.value) AS apagadoCVent

      // Determinar el nuevo estado basado en la tendencia
      WITH corrida, tendencia, now, ventilador, capVent,
            1 / (1 + exp(-(apagadoCVent) * (tendencia - apagadoBVent))) AS mu_apagado,
            exp(-((tendencia - prendidoMediaVent)^2) / (2 * (prendidoSigmaVent^2))) AS mu_prendido

      // Actualizar los valores de pertenencia en el ventilador
      MATCH (slUPrendido:Slot {name:'uPrendido'})
      MATCH (slUApagado:Slot {name:'uApagado'})
      MERGE (ventilador)-[uPrendidoRel:HAS_VALUE {slot:'uPrendido'}]->(slUPrendido)
        ON CREATE SET uPrendidoRel.value = round(mu_prendido, 4), uPrendidoRel.ts = now, uPrendidoRel.source='proc_actualizarEstadosActuadores'
        ON MATCH  SET uPrendidoRel.value = round(mu_prendido, 4), uPrendidoRel.ts = now, uPrendidoRel.source='proc_actualizarEstadosActuadores'
      MERGE (ventilador)-[uApagadoRel:HAS_VALUE {slot:'uApagado'}]->(slUApagado)
        ON CREATE SET uApagadoRel.value = round(mu_apagado, 4), uApagadoRel.ts = now, uApagadoRel.source='proc_actualizarEstadosActuadores'
        ON MATCH  SET uApagadoRel.value = round(mu_apagado, 4), uApagadoRel.ts = now, uApagadoRel.source='proc_actualizarEstadosActuadores'
    }

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

    // Obtener la última lectura asociada a la corrida
    MATCH (corrida)-[ultRel:ULTIMA_LECTURA]->(lectura:Lectura)

    // Obtener los mu de la lectura
    MATCH (slUAlta:Slot {name:'uAlta'})
    MATCH (slUBaja:Slot {name:'uBaja'})
    MATCH (slUEnRango:Slot {name:'uEnRango'})
    MATCH (lectura)-[uAltaRel:HAS_VALUE {slot:'uAlta'}]->(slUAlta)
    MATCH (lectura)-[uBajaRel:HAS_VALUE {slot:'uBaja'}]->(slUBaja)
    MATCH (lectura)-[uEnRangoRel:HAS_VALUE {slot:'uEnRango'}]->(slUEnRango)

    WITH corrida, toFloat(uAltaRel.value) AS mu_alta,
          toFloat(uBajaRel.value) AS mu_baja,
          toFloat(uEnRangoRel.value) AS mu_en_rango,
          datetime() AS now
    
    // Obtenemos los actuadores asociados a la corrida
    MATCH (corrida)-[:TIENE_ACTUADOR]->(calefactor:Actuador {id:'calefactor'})
    MATCH (corrida)-[:TIENE_ACTUADOR]->(ventilador:Actuador {id:'ventilador'})

    // Obtenemos los mu de los actuadores
    MATCH (slUPrendido:Slot {name:'uPrendido'})
    MATCH (slUApagado:Slot {name:'uApagado'})
    MATCH (calefactor)-[uPrendidoCal:HAS_VALUE {slot:'uPrendido'}]->(slUPrendido)
    MATCH (calefactor)-[uApagadoCal:HAS_VALUE {slot:'uApagado'}]->(slUApagado)
    MATCH (ventilador)-[uPrendidoVent:HAS_VALUE {slot:'uPrendido'}]->(slUPrendido)
    MATCH (ventilador)-[uApagadoVent:HAS_VALUE {slot:'uApagado'}]->(slUApagado)

    // MATCH (calefactor)-[rCalefactorActivo:HAS_VALUE {slot:'activo'}]->(:Slot)
    // MATCH (ventilador)-[rVentiladorActivo:HAS_VALUE {slot:'activo'}]->(:Slot)

    WITH corrida, mu_alta, mu_baja, mu_en_rango, now,
          toFloat(uPrendidoCal.value) AS mu_prendido_cal,
          toFloat(uApagadoCal.value) AS mu_apagado_cal,
          toFloat(uPrendidoVent.value) AS mu_prendido_vent,
          toFloat(uApagadoVent.value) AS mu_apagado_vent

    // Obtenemos slot recomendacion
    MATCH (sRecomendaciones:Slot {name:'recomendaciones'})
    MATCH (sUmbral:Slot {name:'umbral'})

    WITH corrida, mu_alta, mu_baja, mu_en_rango, now,
          mu_prendido_cal, mu_apagado_cal, mu_prendido_vent, mu_apagado_vent,
          sRecomendaciones, sUmbral
    

    ////////// ================== TODO: APLICAR LÓGICA DIFUSA ================== //////////|
    // === REGLA_ENCENDER_VENTILADOR ===
    CALL {
      WITH corrida, mu_alta, mu_baja, mu_en_rango, now,
          mu_prendido_cal, mu_apagado_cal, mu_prendido_vent, mu_apagado_vent,
          sRecomendaciones, sUmbral
      MATCH (reco:Recomendacion {id: 'encender_ventilador'}) 
      MATCH (reco)-[uRel:HAS_VALUE {slot:'umbral'}]->(sUmbral)

      WITH corrida, reco, mu_alta, mu_apagado_vent, now, sRecomendaciones,
           apoc.coll.min([mu_alta, mu_apagado_vent]) AS calificacion_encender_ventilador
      WHERE calificacion_encender_ventilador >= toFloat(uRel.value)

      MERGE (corrida)-[:HAS_VALUE {slot:'recomendaciones', value:reco.id, ts:now, source:'proc_actualizarRecomendaciones'}]->(sRecomendaciones)

      MERGE (corrida)-[r:RECOMIENDA {slot:'recomendaciones'}]->(reco)
        ON CREATE SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime(), r.calificacion=calificacion_encender_ventilador
        ON MATCH  SET r.source='trigger_relacionarCorridaRecomendacion', r.ts=datetime(), r.calificacion=calificacion_encender_ventilador
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
    CALL custom.evaluarPrioridadRecomendaciones(corrida.id)
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
MERGE (slTipoFuncionAlta:Slot {name:'tipoFuncionAlta'})
MERGE (slAltaB:Slot {name:'altaB'})
MERGE (slAltaC:Slot {name:'altaC'})
MERGE (slTipoFuncionBaja:Slot {name:'tipoFuncionBaja'})
MERGE (slBajaB:Slot {name:'bajaB'})
MERGE (slBajaC:Slot {name:'bajaC'})
MERGE (slTipoFuncionEnRango:Slot {name:'tipoFuncionEnRango'})
MERGE (slEnRangoMedia:Slot {name:'enRangoMedia'})
MERGE (slEnRangoSigma:Slot {name:'enRangoSigma'})

// Etapa
MERGE (slPrecedeA:Slot {name:'precedeA'})
MERGE (slConfigTemp:Slot {name:'configuracionTemperatura'})

// Actuador
MERGE (slCapacidad:Slot {name:'capacidad'})
// MERGE (slActuadorActivo:Slot {name:'activo'})
MERGE (slTipoFuncionPrendido:Slot {name:'tipoFuncionPrendido'})
MERGE (slPrendidoMedia:Slot {name:'prendidoMedia'})
MERGE (slPrendidoSigma:Slot {name:'prendidoSigma'})
MERGE (slUPrendido:Slot {name:'uPrendido'})
MERGE (slTipoFuncionApagado:Slot {name:'tipoFuncionApagado'})
MERGE (slApagadoB:Slot {name:'apagadoB'})
MERGE (slApagadoC:Slot {name:'apagadoC'})
MERGE (slUApagado:Slot {name:'uApagado'})

// Lectura
MERGE (slTempInt:Slot {name:'temperaturaInterna'})
MERGE (slTendencia:Slot {name:'tendencia'})
MERGE (slCorrida:Slot {name:'corrida'})
MERGE (slEtapa:Slot {name:'etapa'})
// MERGE (slEstado:Slot {name:'estado'})
MERGE (slUAlta:Slot {name:'uAlta'})
MERGE (slUBaja:Slot {name:'uBaja'})
MERGE (slUEnRango:Slot {name:'uEnRango'})

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
MERGE (slUmbral:Slot {name:'umbral'})


// ===================== Declaración de Slots por Clase =====================
// Rango
MERGE (Rango)-[:HAS_SLOT {type:'string',  cardinality:'1',   required:true}]->(slName)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slValorEsperado)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slTolerancia)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:false}]->(slMinimo)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:false}]->(slMaximo)
MERGE (Rango)-[:HAS_SLOT {type:'string',   cardinality:'1',   required:true}]->(slTipoFuncionAlta)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slAltaB)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slAltaC)
MERGE (Rango)-[:HAS_SLOT {type:'string',   cardinality:'1',   required:true}]->(slTipoFuncionBaja)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slBajaB)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slBajaC)
MERGE (Rango)-[:HAS_SLOT {type:'string',   cardinality:'1',   required:true}]->(slTipoFuncionEnRango)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slEnRangoMedia)
MERGE (Rango)-[:HAS_SLOT {type:'float',   cardinality:'1',   required:true}]->(slEnRangoSigma)

// Etapa
MERGE (Etapa)-[:HAS_SLOT {type:'string',  cardinality:'1',   required:true}]->(slName)
MERGE (Etapa)-[:HAS_SLOT {type:'Etapa',   cardinality:'0..1', required:false}]->(slPrecedeA)
MERGE (Etapa)-[:HAS_SLOT {type:'Rango',   cardinality:'1',   required:true}]->(slConfigTemp)

// Actuador
MERGE (Actuador)-[:HAS_SLOT {type:'string',  cardinality:'1', required:true}]->(slName)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:true}]->(slCapacidad)
// MERGE (Actuador)-[:HAS_SLOT {type:'boolean', cardinality:'1', required:true}]->(slActuadorActivo)
MERGE (Actuador)-[:HAS_SLOT {type:'string',  cardinality:'1', required:true}]->(slTipoFuncionPrendido)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:true}]->(slPrendidoMedia)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:true}]->(slPrendidoSigma)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:false}]->(slUPrendido)
MERGE (Actuador)-[:HAS_SLOT {type:'string',  cardinality:'1', required:true}]->(slTipoFuncionApagado)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:true}]->(slApagadoB)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:true}]->(slApagadoC)
MERGE (Actuador)-[:HAS_SLOT {type:'float',   cardinality:'1', required:false}]->(slUApagado)

// Lectura
MERGE (Lectura)-[:HAS_SLOT {type:'string',     cardinality:'1',   required:true}]->(slName)
MERGE (Lectura)-[:HAS_SLOT {type:'datetime',   cardinality:'1',   required:true}]->(slTs)
MERGE (Lectura)-[:HAS_SLOT {type:'float',      cardinality:'1',   required:true, range:'0.0..100.0'}]->(slTempInt)
MERGE (Lectura)-[:HAS_SLOT {type:'float',      cardinality:'1',   required:true}]->(slTendencia)
MERGE (Lectura)-[:HAS_SLOT {type:'Corrida',    cardinality:'1',   required:true}]->(slCorrida)
MERGE (Lectura)-[:HAS_SLOT {type:'Etapa',      cardinality:'1',   required:true}]->(slEtapa)
// MERGE (Lectura)-[:HAS_SLOT {type:'enum',       cardinality:'1',   required:true, enum:['TemperaturaBaja','TemperaturaAlta','TemperaturaEnRango']}]->(slEstado)
MERGE (Lectura)-[:HAS_SLOT {type:'float',     cardinality:'1',   required:false}]->(slUAlta)
MERGE (Lectura)-[:HAS_SLOT {type:'float',     cardinality:'1',   required:false}]->(slUBaja)
MERGE (Lectura)-[:HAS_SLOT {type:'float',     cardinality:'1',   required:false}]->(slUEnRango)

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
MERGE (Recomendacion)-[:HAS_SLOT {type:'float',    cardinality:'1', required:true, range:'0.0..1.0'}]->(slUmbral)



// ===================== Clases derivadas simples (tipos específicos) =====================
// PuertaAbierta e Incendio (frames typeof Alerta). Se modelan como clases específicas.
MERGE (PuertaAbierta:FrameClass {name:'PuertaAbierta'})
MERGE (Incendio:FrameClass {name:'Incendio'})
MERGE (PuertaAbierta)-[:SUBCLASS_OF]->(Alerta)
MERGE (Incendio)-[:SUBCLASS_OF]->(Alerta)

// ===================== Defaults =====================
// MERGE (Actuador)-[:DEFAULT {slot:'activo', value:false}]->(slActuadorActivo)

// MERGE (Lectura)-[:DEFAULT {slot:'estado', value:'TemperaturaEnRango'}]->(slEstado)
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

// MERGE (slActuadorActivo)-[ModificaActivoActuador:IF_NEEDED]->(dUpdEstadoActuador)
//   ON CREATE SET ModificaActivoActuador.ts = datetime(), ModificaActivoActuador.source='seed'
//   ON MATCH  SET ModificaActivoActuador.ts = datetime()

MERGE (slUPrendido)-[ModificaPrendidoActuador:IF_NEEDED]->(dUpdEstadoActuador)
  ON CREATE SET ModificaPrendidoActuador.ts = datetime(), ModificaPrendidoActuador.source='seed'
  ON MATCH  SET ModificaPrendidoActuador.ts = datetime()

MERGE (slUApagado)-[ModificaApagadoctuador:IF_NEEDED]->(dUpdEstadoActuador)
  ON CREATE SET ModificaApagadoctuador.ts = datetime(), ModificaApagadoctuador.source='seed'
  ON MATCH  SET ModificaApagadoctuador.ts = datetime()

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
MERGE (dUpdEstadoActuador)-[:UPDATES]->(slUPrendido)
MERGE (dUpdEstadoActuador)-[:UPDATES]->(slUApagado)
MERGE (dUpdTemp)-[:UPDATES]->(slUltimaLectura)
MERGE (dUpdEstadoTemp)-[:UPDATES]->(slUAlta)
MERGE (dUpdEstadoTemp)-[:UPDATES]->(slUBaja)
MERGE (dUpdEstadoTemp)-[:UPDATES]->(slUEnRango)
MERGE (dEvalAlertas)-[:UPDATES]->(slAlertas)
MERGE (dEvalPrioridadRec)-[:UPDATES]->(slRecomendaciones)
MERGE (dEvalRecomendaciones)-[:UPDATES]->(slRecomendaciones)

// ===================== Instancias (FrameInstance) =====================
// Rangos (Temp80 / Temp30)
MERGE (temp80:FrameInstance:Rango {id:'temp_80'})-[:INSTANCE_OF]->(Rango)
MERGE (temp80)-[nTemp80:HAS_VALUE {slot:'name',           value:'Rango de temperatura para proceso térmico'}]->(slName)
  ON CREATE SET nTemp80.source='seed', nTemp80.ts=datetime()
  ON MATCH  SET nTemp80.source='seed', nTemp80.ts=datetime()
MERGE (temp80)-[veTemp80:HAS_VALUE {slot:'valorEsperado',  value:80.0}]->(slValorEsperado)
  ON CREATE SET veTemp80.source='seed', veTemp80.ts=datetime()
  ON MATCH  SET veTemp80.source='seed', veTemp80.ts=datetime()
MERGE (temp80)-[tTemp80:HAS_VALUE {slot:'tolerancia',     value:3.0}]->(slTolerancia)
  ON CREATE SET tTemp80.source='seed', tTemp80.ts=datetime()
  ON MATCH  SET tTemp80.source='seed', tTemp80.ts=datetime()
MERGE (temp80)-[minTemp80:HAS_VALUE {slot:'minimo',         value:77.0}]->(slMinimo)
  ON CREATE SET minTemp80.source='seed', minTemp80.ts=datetime()
  ON MATCH  SET minTemp80.source='seed', minTemp80.ts=datetime()
MERGE (temp80)-[maxTemp80:HAS_VALUE {slot:'maximo',         value:83.0}]->(slMaximo)
  ON CREATE SET maxTemp80.source='seed', maxTemp80.ts=datetime()
  ON MATCH  SET maxTemp80.source='seed', maxTemp80.ts=datetime()
MERGE (temp80)-[tipoFuncionAltaTemp80:HAS_VALUE {slot:'tipoFuncionAlta', value:'sigmoide'}]->(slTipoFuncionAlta)
  ON CREATE SET tipoFuncionAltaTemp80.source='seed', tipoFuncionAltaTemp80.ts=datetime()
  ON MATCH  SET tipoFuncionAltaTemp80.source='seed', tipoFuncionAltaTemp80.ts=datetime()
MERGE (temp80)-[altaBTemp80:HAS_VALUE {slot:'altaB', value:84.0}]->(slAltaB)
  ON CREATE SET altaBTemp80.source='seed', altaBTemp80.ts=datetime()
  ON MATCH  SET altaBTemp80.source='seed', altaBTemp80.ts=datetime()
MERGE (temp80)-[altaCTemp80:HAS_VALUE {slot:'altaC', value:0.3}]->(slAltaC)
  ON CREATE SET altaCTemp80.source='seed', altaCTemp80.ts=datetime()
  ON MATCH  SET altaCTemp80.source='seed', altaCTemp80.ts=datetime()
MERGE (temp80)-[tipoFuncionBajaTemp80:HAS_VALUE {slot:'tipoFuncionBaja', value:'sigmoide'}]->(slTipoFuncionBaja)
  ON CREATE SET tipoFuncionBajaTemp80.source='seed', tipoFuncionBajaTemp80.ts=datetime()
  ON MATCH  SET tipoFuncionBajaTemp80.source='seed', tipoFuncionBajaTemp80.ts=datetime()
MERGE (temp80)-[bajaBTemp80:HAS_VALUE {slot:'bajaB', value:76.0}]->(slBajaB)
  ON CREATE SET bajaBTemp80.source='seed', bajaBTemp80.ts=datetime()
  ON MATCH  SET bajaBTemp80.source='seed', bajaBTemp80.ts=datetime()
MERGE (temp80)-[bajaCTemp80:HAS_VALUE {slot:'bajaC', value:-0.3}]->(slBajaC)
  ON CREATE SET bajaCTemp80.source='seed', bajaCTemp80.ts=datetime()
  ON MATCH  SET bajaCTemp80.source='seed', bajaCTemp80.ts=datetime()
MERGE (temp80)-[tipoFuncionEnRangoTemp80:HAS_VALUE {slot:'tipoFuncionEnRango', value:'gaussiana'}]->(slTipoFuncionEnRango)
  ON CREATE SET tipoFuncionEnRangoTemp80.source='seed', tipoFuncionEnRangoTemp80.ts=datetime()
  ON MATCH  SET tipoFuncionEnRangoTemp80.source='seed', tipoFuncionEnRangoTemp80.ts=datetime()
MERGE (temp80)-[enRangoMediaTemp80:HAS_VALUE {slot:'enRangoMedia', value:80.0}]->(slEnRangoMedia)
  ON CREATE SET enRangoMediaTemp80.source='seed', enRangoMediaTemp80.ts=datetime()
  ON MATCH  SET enRangoMediaTemp80.source='seed', enRangoMediaTemp80.ts=datetime()
MERGE (temp80)-[enRangoSigmaTemp80:HAS_VALUE {slot:'enRangoSigma', value:2.55}]->(slEnRangoSigma)
  ON CREATE SET enRangoSigmaTemp80.source='seed', enRangoSigmaTemp80.ts=datetime()
  ON MATCH  SET enRangoSigmaTemp80.source='seed', enRangoSigmaTemp80.ts=datetime()

MERGE (temp30:FrameInstance:Rango {id:'temp_30'})-[:INSTANCE_OF]->(Rango)
MERGE (temp30)-[nTemp30:HAS_VALUE {slot:'name',           value:'Rango de temperatura para enfriamiento'}]->(slName)
  ON CREATE SET nTemp30.source='seed', nTemp30.ts=datetime()
  ON MATCH  SET nTemp30.source='seed', nTemp30.ts=datetime()
MERGE (temp30)-[veTemp30:HAS_VALUE {slot:'valorEsperado',  value:30.0}]->(slValorEsperado)
  ON CREATE SET veTemp30.source='seed', veTemp30.ts=datetime()
  ON MATCH  SET veTemp30.source='seed', veTemp30.ts=datetime()
MERGE (temp30)-[tTemp30:HAS_VALUE {slot:'tolerancia',     value:3.0}]->(slTolerancia)
  ON CREATE SET tTemp30.source='seed', tTemp30.ts=datetime()
  ON MATCH  SET tTemp30.source='seed', tTemp30.ts=datetime()
MERGE (temp30)-[minTemp30:HAS_VALUE {slot:'minimo',         value:27.0}]->(slMinimo)
  ON CREATE SET minTemp30.source='seed', minTemp30.ts=datetime()
  ON MATCH  SET minTemp30.source='seed', minTemp30.ts=datetime()
MERGE (temp30)-[maxTemp30:HAS_VALUE {slot:'maximo',         value:33.0}]->(slMaximo)
  ON CREATE SET maxTemp30.source='seed', maxTemp30.ts=datetime()
  ON MATCH  SET maxTemp30.source='seed', maxTemp30.ts=datetime()
MERGE (temp30)-[tipoFuncionAltaTemp30:HAS_VALUE {slot:'tipoFuncionAlta', value:'sigmoide'}]->(slTipoFuncionAlta)
  ON CREATE SET tipoFuncionAltaTemp30.source='seed', tipoFuncionAltaTemp30.ts=datetime()
  ON MATCH  SET tipoFuncionAltaTemp30.source='seed', tipoFuncionAltaTemp30.ts=datetime()
MERGE (temp30)-[altaBTemp30:HAS_VALUE {slot:'altaB', value:34.0}]->(slAltaB)
  ON CREATE SET altaBTemp30.source='seed', altaBTemp30.ts=datetime()
  ON MATCH  SET altaBTemp30.source='seed', altaBTemp30.ts=datetime()
MERGE (temp30)-[altaCTemp30:HAS_VALUE {slot:'altaC', value:0.3}]->(slAltaC)
  ON CREATE SET altaCTemp30.source='seed', altaCTemp30.ts=datetime()
  ON MATCH  SET altaCTemp30.source='seed', altaCTemp30.ts=datetime()
MERGE (temp30)-[tipoFuncionBajaTemp30:HAS_VALUE {slot:'tipoFuncionBaja', value:'sigmoide'}]->(slTipoFuncionBaja)
  ON CREATE SET tipoFuncionBajaTemp30.source='seed', tipoFuncionBajaTemp30.ts=datetime()
  ON MATCH  SET tipoFuncionBajaTemp30.source='seed', tipoFuncionBajaTemp30.ts=datetime()
MERGE (temp30)-[bajaBTemp30:HAS_VALUE {slot:'bajaB', value:26.0}]->(slBajaB)
  ON CREATE SET bajaBTemp30.source='seed', bajaBTemp30.ts=datetime()
  ON MATCH  SET bajaBTemp30.source='seed', bajaBTemp30.ts=datetime()
MERGE (temp30)-[bajaCTemp30:HAS_VALUE {slot:'bajaC', value:-0.3}]->(slBajaC)
  ON CREATE SET bajaCTemp30.source='seed', bajaCTemp30.ts=datetime()
  ON MATCH  SET bajaCTemp30.source='seed', bajaCTemp30.ts=datetime()
MERGE (temp30)-[tipoFuncionEnRangoTemp30:HAS_VALUE {slot:'tipoFuncionEnRango', value:'gaussiana'}]->(slTipoFuncionEnRango)
  ON CREATE SET tipoFuncionEnRangoTemp30.source='seed', tipoFuncionEnRangoTemp30.ts=datetime()
  ON MATCH  SET tipoFuncionEnRangoTemp30.source='seed', tipoFuncionEnRangoTemp30.ts=datetime()
MERGE (temp30)-[enRangoMediaTemp30:HAS_VALUE {slot:'enRangoMedia', value:30.0}]->(slEnRangoMedia)
  ON CREATE SET enRangoMediaTemp30.source='seed', enRangoMediaTemp30.ts=datetime()
  ON MATCH  SET enRangoMediaTemp30.source='seed', enRangoMediaTemp30.ts=datetime()
MERGE (temp30)-[enRangoSigmaTemp30:HAS_VALUE {slot:'enRangoSigma', value:2.55}]->(slEnRangoSigma)
  ON CREATE SET enRangoSigmaTemp30.source='seed', enRangoSigmaTemp30.ts=datetime()
  ON MATCH  SET enRangoSigmaTemp30.source='seed', enRangoSigmaTemp30.ts=datetime()

// Etapas (ProcesoTérmico / Enfriamiento)
MERGE (enf:FrameInstance:Etapa {id:'enfriamiento'})-[:INSTANCE_OF]->(Etapa)
MERGE (enf)-[nEnf:HAS_VALUE {slot:'name', value:'Enfriamiento'}]->(slName)
  ON CREATE SET nEnf.source='seed', nEnf.ts=datetime()
  ON MATCH  SET nEnf.source='seed', nEnf.ts=datetime()
MERGE (enf)-[ctEnf:HAS_VALUE {slot:'configuracionTemperatura', value:'temp_30'}]->(slConfigTemp)
  ON CREATE SET ctEnf.source='seed', ctEnf.ts=datetime()
  ON MATCH  SET ctEnf.source='seed', ctEnf.ts=datetime()
MERGE (enf)-[enfTemp30:CONFIGURACION_TEMPERATURA]->(temp30)
  ON CREATE SET enfTemp30.source='seed', enfTemp30.ts=datetime()
  ON MATCH  SET enfTemp30.source='seed', enfTemp30.ts=datetime()

MERGE (procT:FrameInstance:Etapa {id:'proceso_termico'})-[:INSTANCE_OF]->(Etapa)
MERGE (procT)-[nProcT:HAS_VALUE {slot:'name', value:'Proceso Térmico'}]->(slName)
  ON CREATE SET nProcT.source='seed', nProcT.ts=datetime()
  ON MATCH  SET nProcT.source='seed', nProcT.ts=datetime()
MERGE (procT)-[ctProcT:HAS_VALUE {slot:'configuracionTemperatura', value:'temp_80'}]->(slConfigTemp)
  ON CREATE SET ctProcT.source='seed', ctProcT.ts=datetime()
  ON MATCH  SET ctProcT.source='seed', ctProcT.ts=datetime()
MERGE (procT)-[procTTemp80:CONFIGURACION_TEMPERATURA]->(temp80)
  ON CREATE SET procTTemp80.source='seed', procTTemp80.ts=datetime()
  ON MATCH  SET procTTemp80.source='seed', procTTemp80.ts=datetime()
MERGE (procT)-[precedeA:HAS_VALUE {slot:'precedeA', value:'enfriamiento'}]->(slPrecedeA)
  ON CREATE SET precedeA.source='seed', precedeA.ts=datetime()
  ON MATCH  SET precedeA.source='seed', precedeA.ts=datetime()
MERGE (procT)-[procTEnf:PRECEDE_A]->(enf)
  ON CREATE SET procTEnf.source='seed', procTEnf.ts=datetime()
  ON MATCH  SET procTEnf.source='seed', procTEnf.ts=datetime()

MERGE (Corrida)-[corridaProcT:INICIA_EN {slot: 'etapaActual'}]-(procT)
  ON CREATE SET corridaProcT.source='seed', corridaProcT.ts=datetime()
  ON MATCH  SET corridaProcT.source='seed', corridaProcT.ts=datetime()

// Actuadores (Calefactor / Ventilador)
MERGE (cal:FrameInstance:Actuador {id:'calefactor'})-[:INSTANCE_OF]->(Actuador)
  MERGE (cal)-[nCal:HAS_VALUE {slot:'name',     value:'Calefactor'}]->(slName)
  ON CREATE SET nCal.source='seed', nCal.ts=datetime()
  ON MATCH  SET nCal.source='seed', nCal.ts=datetime()

MERGE (cal)-[cCal:HAS_VALUE {slot:'capacidad',value:1.0}]->(slCapacidad)
  ON CREATE SET cCal.source='seed', cCal.ts=datetime()
  ON MATCH  SET cCal.source='seed', cCal.ts=datetime()

MERGE (cal)-[tfpCal:HAS_VALUE {slot:'tipoFuncionPrendido', value:'gaussiana'}]->(slTipoFuncionPrendido)
  ON CREATE SET tfpCal.source='seed', tfpCal.ts=datetime()
  ON MATCH  SET tfpCal.source='seed', tfpCal.ts=datetime()
MERGE (cal)-[pMediaCal:HAS_VALUE {slot:'prendidoMedia', value:1.0}]->(slPrendidoMedia)
  ON CREATE SET pMediaCal.source='seed', pMediaCal.ts=datetime()
  ON MATCH  SET pMediaCal.source='seed', pMediaCal.ts=datetime()
MERGE (cal)-[pSigmaCal:HAS_VALUE {slot:'prendidoSigma', value:0.5}]->(slPrendidoSigma)
  ON CREATE SET pSigmaCal.source='seed', pSigmaCal.ts=datetime()
  ON MATCH  SET pSigmaCal.source='seed', pSigmaCal.ts=datetime()
MERGE (cal)-[tfaCal:HAS_VALUE {slot:'tipoFuncionApagado', value:'sigmoide'}]->(slTipoFuncionApagado)
  ON CREATE SET tfaCal.source='seed', tfaCal.ts=datetime()
  ON MATCH  SET tfaCal.source='seed', tfaCal.ts=datetime()
MERGE (cal)-[aBCal:HAS_VALUE {slot:'apagadoB', value:0.4}]->(slApagadoB)
  ON CREATE SET aBCal.source='seed', aBCal.ts=datetime()
  ON MATCH  SET aBCal.source='seed', aBCal.ts=datetime()
MERGE (cal)-[aCCal:HAS_VALUE {slot:'apagadoC', value:-10}]->(slApagadoC)
  ON CREATE SET aCCal.source='seed', aCCal.ts=datetime()
  ON MATCH  SET aCCal.source='seed', aCCal.ts=datetime()

// MERGE (cal)-[aCal:HAS_VALUE {slot:'activo',   value:false}]->(slActuadorActivo)
//   ON CREATE SET aCal.source='seed', aCal.ts=datetime()
//   ON MATCH  SET aCal.source='seed', aCal.ts=datetime()

MERGE (ven:FrameInstance:Actuador {id:'ventilador'})-[:INSTANCE_OF]->(Actuador)
MERGE (ven)-[nVen:HAS_VALUE {slot:'name',     value:'Ventilador'}]->(slName)
  ON CREATE SET nVen.source='seed', nVen.ts=datetime()
  ON MATCH  SET nVen.source='seed', nVen.ts=datetime()

MERGE (ven)-[cVen:HAS_VALUE {slot:'capacidad',value:-0.5}]->(slCapacidad)
  ON CREATE SET cVen.source='seed', cVen.ts=datetime()
  ON MATCH  SET cVen.source='seed', cVen.ts=datetime()

MERGE (ven)-[tfpVen:HAS_VALUE {slot:'tipoFuncionPrendido', value:'gaussiana'}]->(slTipoFuncionPrendido)
  ON CREATE SET tfpVen.source='seed', tfpVen.ts=datetime()
  ON MATCH  SET tfpVen.source='seed', tfpVen.ts=datetime()
MERGE (ven)-[pMediaVen:HAS_VALUE {slot:'prendidoMedia', value:-0.06}]->(slPrendidoMedia)
  ON CREATE SET pMediaVen.source='seed', pMediaVen.ts=datetime()
  ON MATCH  SET pMediaVen.source='seed', pMediaVen.ts=datetime()
MERGE (ven)-[pSigmaVen:HAS_VALUE {slot:'prendidoSigma', value:0.6}]->(slPrendidoSigma)
  ON CREATE SET pSigmaVen.source='seed', pSigmaVen.ts=datetime()
  ON MATCH  SET pSigmaVen.source='seed', pSigmaVen.ts=datetime()
MERGE (ven)-[tfaVen:HAS_VALUE {slot:'tipoFuncionApagado', value:'sigmoide'}]->(slTipoFuncionApagado)
  ON CREATE SET tfaVen.source='seed', tfaVen.ts=datetime()
  ON MATCH  SET tfaVen.source='seed', tfaVen.ts=datetime()
MERGE (ven)-[aBVen:HAS_VALUE {slot:'apagadoB', value:-0.04}]->(slApagadoB)
  ON CREATE SET aBVen.source='seed', aBVen.ts=datetime()
  ON MATCH  SET aBVen.source='seed', aBVen.ts=datetime()
MERGE (ven)-[aCVen:HAS_VALUE {slot:'apagadoC', value:10}]->(slApagadoC)
  ON CREATE SET aCVen.source='seed', aCVen.ts=datetime()
  ON MATCH  SET aCVen.source='seed', aCVen.ts=datetime()

// MERGE (ven)-[aVen:HAS_VALUE {slot:'activo',   value:false}]->(slActuadorActivo)
//   ON CREATE SET aVen.source='seed', aVen.ts=datetime()
//   ON MATCH  SET aVen.source='seed', aVen.ts=datetime()

// Recomendaciones (instancias) + conflictos
MERGE (recEV:FrameInstance:Recomendacion {id:'encender_ventilador'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recEV)-[nRecEV:HAS_VALUE {slot:'name',      value:'EncenderVentilador'}]->(slName)
  ON CREATE SET nRecEV.source='seed', nRecEV.ts=datetime()
  ON MATCH  SET nRecEV.source='seed', nRecEV.ts=datetime()
MERGE (recEV)-[pRecEV:HAS_VALUE {slot:'prioridad', value:9}]->(slPrioridad)
  ON CREATE SET pRecEV.source='seed', pRecEV.ts=datetime()
  ON MATCH  SET pRecEV.source='seed', pRecEV.ts=datetime()
MERGE (recEV)-[uRecEV:HAS_VALUE {slot:'umbral',   value:0.5}]->(slUmbral)
  ON CREATE SET uRecEV.source='seed', uRecEV.ts=datetime()
  ON MATCH  SET uRecEV.source='seed', uRecEV.ts=datetime()

MERGE (recAV:FrameInstance:Recomendacion {id:'apagar_ventilador'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recAV)-[nRecAV:HAS_VALUE {slot:'name',      value:'ApagarVentilador'}]->(slName)
  ON CREATE SET nRecAV.source='seed', nRecAV.ts=datetime()
  ON MATCH  SET nRecAV.source='seed', nRecAV.ts=datetime()
MERGE (recAV)-[pRecAV:HAS_VALUE {slot:'prioridad', value:8}]->(slPrioridad)
  ON CREATE SET pRecAV.source='seed', pRecAV.ts=datetime()
  ON MATCH  SET pRecAV.source='seed', pRecAV.ts=datetime()
MERGE (recAV)-[uRecAV:HAS_VALUE {slot:'umbral',   value:0.5}]->(slUmbral)
  ON CREATE SET uRecAV.source='seed', uRecAV.ts=datetime()
  ON MATCH  SET uRecAV.source='seed', uRecAV.ts=datetime()


MERGE (recEC:FrameInstance:Recomendacion {id:'encender_calefactor'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recEC)-[nRecEC:HAS_VALUE {slot:'name',      value:'EncenderCalefactor'}]->(slName)
  ON CREATE SET nRecEC.source='seed', nRecEC.ts=datetime()
  ON MATCH  SET nRecEC.source='seed', nRecEC.ts=datetime()
MERGE (recEC)-[pRecEC:HAS_VALUE {slot:'prioridad', value:9}]->(slPrioridad)
  ON CREATE SET pRecEC.source='seed', pRecEC.ts=datetime()
  ON MATCH  SET pRecEC.source='seed', pRecEC.ts=datetime()
MERGE (recEC)-[uRecEC:HAS_VALUE {slot:'umbral',   value:0.5}]->(slUmbral)
  ON CREATE SET uRecEC.source='seed', uRecEC.ts=datetime()
  ON MATCH  SET uRecEC.source='seed', uRecEC.ts=datetime()

MERGE (recAC:FrameInstance:Recomendacion {id:'apagar_calefactor'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recAC)-[nRecAC:HAS_VALUE {slot:'name',      value:'ApagarCalefactor'}]->(slName)
  ON CREATE SET nRecAC.source='seed', nRecAC.ts=datetime()
  ON MATCH  SET nRecAC.source='seed', nRecAC.ts=datetime()
MERGE (recAC)-[pRecAC:HAS_VALUE {slot:'prioridad', value:10}]->(slPrioridad)
  ON CREATE SET pRecAC.source='seed', pRecAC.ts=datetime()
  ON MATCH  SET pRecAC.source='seed', pRecAC.ts=datetime()
MERGE (recAC)-[uRecAC:HAS_VALUE {slot:'umbral',   value:0.5}]->(slUmbral)
  ON CREATE SET uRecAC.source='seed', uRecAC.ts=datetime()
  ON MATCH  SET uRecAC.source='seed', uRecAC.ts=datetime()

MERGE (recM:FrameInstance:Recomendacion {id:'mantener_estado_actual'})-[:INSTANCE_OF]->(Recomendacion)
MERGE (recM)-[nRecM:HAS_VALUE {slot:'name',      value:'MantenerEstadoActual'}]->(slName)
  ON CREATE SET nRecM.source='seed', nRecM.ts=datetime()
  ON MATCH  SET nRecM.source='seed', nRecM.ts=datetime()
MERGE (recM)-[pRecM:HAS_VALUE {slot:'prioridad', value:1}]->(slPrioridad)
  ON CREATE SET pRecM.source='seed', pRecM.ts=datetime()
  ON MATCH  SET pRecM.source='seed', pRecM.ts=datetime()
MERGE (recM)-[uRecM:HAS_VALUE {slot:'umbral',   value:0.5}]->(slUmbral)
  ON CREATE SET uRecM.source='seed', uRecM.ts=datetime()
  ON MATCH  SET uRecM.source='seed', uRecM.ts=datetime()

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
CALL apoc.util.sleep(4000); // Esperar a que se creen los índices y constraints

CALL db.clearQueryCaches(); // Borrar caches de consultas

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