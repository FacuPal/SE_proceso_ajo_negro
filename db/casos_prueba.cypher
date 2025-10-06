// Crear una Corrida en etapa proceso_termico
MATCH (Corrida:FrameClass {name:'Corrida'})
MATCH (slName:Slot {name:'name'})
MATCH (slFechaInicio:Slot {name:'fechaInicio'})
MATCH (slEtapaActual:Slot {name:'etapaActual'})
MATCH (slActuadores:Slot {name:'actuadores'})
MATCH (procT:FrameInstance:Etapa {id:'proceso_termico'})

MERGE (c:FrameInstance:Corrida {id:'corrida_2025_10_03_01'})-[:INSTANCE_OF]->(Corrida)
WITH c, slName, slFechaInicio, slEtapaActual, slActuadores, procT, datetime() AS now

MERGE (c)-[rName:HAS_VALUE {slot:'name'}]->(slName)
  ON CREATE SET rName.value = 'Corrida de prueba 2025-10-03', rName.ts = now
  ON MATCH  SET rName.value = 'Corrida de prueba 2025-10-03', rName.ts = now

MERGE (c)-[rIni:HAS_VALUE {slot:'fechaInicio'}]->(slFechaInicio)
  ON CREATE SET rIni.value = date(), rIni.ts = now
  ON MATCH  SET rIni.value = date(), rIni.ts = now

// Guardamos el id de la etapa como valor del slot y creamos la relación a la instancia
MERGE (c)-[rEt:HAS_VALUE {slot:'etapaActual'}]->(slEtapaActual)
  ON CREATE SET rEt.value = 'proceso_termico', rEt.ts = now
  ON MATCH  SET rEt.value = 'proceso_termico', rEt.ts = now

// Lista de actuadores iniciales (coincide con defaults del modelo)
// Crear relacion a calefactor
MERGE (c)-[rCal:HAS_VALUE {slot:'actuadores', value: 'calefactor'}]->(slActuadores)
  ON CREATE SET rCal.ts = now
  ON MATCH  SET rCal.ts = now

MERGE (c)-[rVent:HAS_VALUE {slot:'actuadores', value: 'ventilador'}]->(slActuadores)
  ON CREATE SET rVent.ts = now
  ON MATCH  SET rVent.ts = now;

CALL apoc.util.sleep(1000); // Esperar 1 segundo para diferenciar timestamps

// Crear una Lectura asociada a la Corrida como última lectura 
// tendencia 2 => Calefactor prendido y ventilador apagado
MATCH (c:Corrida)-[:ETAPA_ACTUAL]->(etapa:Etapa)
OPTIONAL MATCH (c)-[r:HAS_VALUE {slot: 'fechaFin'}]->()
WHERE r IS NULL OR r.value IS NULL
MATCH (LectClass:FrameClass {name:'Lectura'})
MATCH (slLName:Slot {name:'name'})
MATCH (slTs:Slot {name:'ts'})
MATCH (slTempInt:Slot {name:'temperaturaInterna'})
MATCH (slTendencia:Slot {name:'tendencia'})
MATCH (slLCorrida:Slot {name:'corrida'})
MATCH (slLEtapa:Slot {name:'etapa'})
MATCH (slLEstado:Slot {name:'estado'})
MATCH (slUltimaLectura:Slot {name:'ultimaLectura'})
MATCH (procT:FrameInstance:Etapa {id:'proceso_termico'})
WITH c, LectClass, slLName, slTs, slTempInt, slTendencia, slLCorrida, 
      slLEtapa, slLEstado, slUltimaLectura, procT, datetime() AS now,
      86.0 AS tempInt, 2 AS tendencia

MERGE (l:FrameInstance:Lectura {id:'lectura_' + apoc.create.uuid()})-[:INSTANCE_OF]->(LectClass)
MERGE (l)-[lvName:HAS_VALUE {slot:'name'}]->(slLName)
  ON CREATE SET lvName.value = 'Lectura de ' + c.id, lvName.ts = now
  ON MATCH  SET lvName.value = 'Lectura de ' + c.id, lvName.ts = now

MERGE (l)-[lvTs:HAS_VALUE {slot:'ts'}]->(slTs)
  ON CREATE SET lvTs.value = now, lvTs.ts = now
  ON MATCH  SET lvTs.value = now, lvTs.ts = now

// Valores de ejemplo: temperatura y estado
MERGE (l)-[lvTemp:HAS_VALUE {slot:'temperaturaInterna'}]->(slTempInt)
  ON CREATE SET lvTemp.value = tempInt, lvTemp.ts = now
  ON MATCH  SET lvTemp.value = tempInt, lvTemp.ts = now

MERGE (l)-[lvTend:HAS_VALUE {slot:'tendencia'}]->(slTendencia)
  ON CREATE SET lvTend.value = tendencia, lvTend.ts = now
  ON MATCH  SET lvTend.value = tendencia, lvTend.ts = now

// MERGE (l)-[lvEst:HAS_VALUE {slot:'estado'}]->(slLEstado)
//   ON CREATE SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now
//   ON MATCH  SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now

// Referencias: corrida y etapa (valor + relación)
MERGE (l)-[lvCorr:HAS_VALUE {slot:'corrida'}]->(slLCorrida)
  ON CREATE SET lvCorr.value = c.id, lvCorr.ts = now
  ON MATCH  SET lvCorr.value = c.id, lvCorr.ts = now

MERGE (l)-[lvEt:HAS_VALUE {slot:'etapa'}]->(slLEtapa)
  ON CREATE SET lvEt.value = 'proceso_termico', lvEt.ts = now
  ON MATCH  SET lvEt.value = 'proceso_termico', lvEt.ts = now;


// -------------------------------------------------------------------//
// Genero otra lectura para probar el trigger
// Tendencia 0.5 => calefactor y ventilador prendido
MATCH (c:FrameInstance:Corrida {id:'corrida_2025_10_03_01'})-[:ETAPA_ACTUAL]->(etapa:Etapa)
MATCH (LectClass:FrameClass {name:'Lectura'})
MATCH (slLName:Slot {name:'name'})
MATCH (slTs:Slot {name:'ts'})
MATCH (slTempInt:Slot {name:'temperaturaInterna'})
MATCH (slTendencia:Slot {name:'tendencia'})
MATCH (slLCorrida:Slot {name:'corrida'})
MATCH (slLEtapa:Slot {name:'etapa'})
MATCH (slLEstado:Slot {name:'estado'})
MATCH (slUltimaLectura:Slot {name:'ultimaLectura'})
WITH c, LectClass, slLName, slTs, slTempInt, slTendencia, slLCorrida, slLEtapa, slLEstado, slUltimaLectura, etapa, datetime() AS now

MERGE (l:FrameInstance:Lectura {id:'lectura_2025_10_03_02'})-[:INSTANCE_OF]->(LectClass)
MERGE (l)-[lvName:HAS_VALUE {slot:'name'}]->(slLName)
  ON CREATE SET lvName.value = 'Lectura Corrida 2025-10-03 02', lvName.ts = now
  ON MATCH  SET lvName.value = 'Lectura Corrida 2025-10-03 02', lvName.ts = now

MERGE (l)-[lvTs:HAS_VALUE {slot:'ts'}]->(slTs)
  ON CREATE SET lvTs.value = now, lvTs.ts = now
  ON MATCH  SET lvTs.value = now, lvTs.ts = now

// Valores de ejemplo: temperatura y estado
MERGE (l)-[lvTemp:HAS_VALUE {slot:'temperaturaInterna'}]->(slTempInt)
  ON CREATE SET lvTemp.value = 81.0, lvTemp.ts = now
  ON MATCH  SET lvTemp.value = 81.0, lvTemp.ts = now

MERGE (l)-[lvTend:HAS_VALUE {slot:'tendencia'}]->(slTendencia)
  ON CREATE SET lvTend.value = 0.5, lvTend.ts = now
  ON MATCH  SET lvTend.value = 0.5, lvTend.ts = now

MERGE (l)-[lvEst:HAS_VALUE {slot:'estado'}]->(slLEstado)
  ON CREATE SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now
  ON MATCH  SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now

// Referencias: corrida y etapa (valor + relación)
MERGE (l)-[lvCorr:HAS_VALUE {slot:'corrida'}]->(slLCorrida)
  ON CREATE SET lvCorr.value = c.id, lvCorr.ts = now
  ON MATCH  SET lvCorr.value = c.id, lvCorr.ts = now
// MERGE (l)-[:DE_CORRIDA {slot:'corrida', ts:now}]->(c)

MERGE (l)-[lvEt:HAS_VALUE {slot:'etapa'}]->(slLEtapa)
  ON CREATE SET lvEt.value = etapa.id, lvEt.ts = now
  ON MATCH  SET lvEt.value = etapa.id, lvEt.ts = now;
// MERGE (l)-[:EN_ETAPA {slot:'etapa', ts:now}]->(etapa);

// -------------------------------------------------------------------//
// Otra lectura
// tendencia -1 => ventilador prendido y calefactor apagado
MATCH (c:FrameInstance:Corrida {id:'corrida_2025_10_03_01'})-[:ETAPA_ACTUAL]->(etapa:Etapa)
MATCH (LectClass:FrameClass {name:'Lectura'})
MATCH (slLName:Slot {name:'name'})
MATCH (slTs:Slot {name:'ts'})
MATCH (slTempInt:Slot {name:'temperaturaInterna'})
MATCH (slTendencia:Slot {name:'tendencia'})
MATCH (slLCorrida:Slot {name:'corrida'})
MATCH (slLEtapa:Slot {name:'etapa'})
MATCH (slLEstado:Slot {name:'estado'})
MATCH (slUltimaLectura:Slot {name:'ultimaLectura'})
WITH c, LectClass, slLName, slTs, slTempInt, slTendencia, slLCorrida, slLEtapa, slLEstado, slUltimaLectura, etapa, datetime() AS now

MERGE (l:FrameInstance:Lectura {id:'lectura_2025_10_03_03'})-[:INSTANCE_OF]->(LectClass)
MERGE (l)-[lvName:HAS_VALUE {slot:'name'}]->(slLName)
  ON CREATE SET lvName.value = 'Lectura Corrida 2025-10-03 03', lvName.ts = now
  ON MATCH  SET lvName.value = 'Lectura Corrida 2025-10-03 03', lvName.ts = now

MERGE (l)-[lvTs:HAS_VALUE {slot:'ts'}]->(slTs)
  ON CREATE SET lvTs.value = now, lvTs.ts = now
  ON MATCH  SET lvTs.value = now, lvTs.ts = now

// Valores de ejemplo: temperatura y estado
MERGE (l)-[lvTemp:HAS_VALUE {slot:'temperaturaInterna'}]->(slTempInt)
  ON CREATE SET lvTemp.value = 81.0, lvTemp.ts = now
  ON MATCH  SET lvTemp.value = 81.0, lvTemp.ts = now

MERGE (l)-[lvTend:HAS_VALUE {slot:'tendencia'}]->(slTendencia)
  ON CREATE SET lvTend.value = 0.1, lvTend.ts = now
  ON MATCH  SET lvTend.value = 0.1, lvTend.ts = now

MERGE (l)-[lvEst:HAS_VALUE {slot:'estado'}]->(slLEstado)
  ON CREATE SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now
  ON MATCH  SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now

// Referencias: corrida y etapa (valor + relación)
MERGE (l)-[lvCorr:HAS_VALUE {slot:'corrida'}]->(slLCorrida)
  ON CREATE SET lvCorr.value = c.id, lvCorr.ts = now
  ON MATCH  SET lvCorr.value = c.id, lvCorr.ts = now
MERGE (l)-[:DE_CORRIDA {slot:'corrida', ts:now}]->(c)

MERGE (l)-[lvEt:HAS_VALUE {slot:'etapa'}]->(slLEtapa)
  ON CREATE SET lvEt.value = etapa.id, lvEt.ts = now
  ON MATCH  SET lvEt.value = etapa.id, lvEt.ts = now
MERGE (l)-[:EN_ETAPA {slot:'etapa', ts:now}]->(etapa);

// -------------------------------------------------------------------//
// Otra lectura
// tendencia 0 => ventilador y calefactor apagado
MATCH (c:FrameInstance:Corrida {id:'corrida_2025_10_03_01'})-[:ETAPA_ACTUAL]->(etapa:Etapa)
MATCH (LectClass:FrameClass {name:'Lectura'})
MATCH (slLName:Slot {name:'name'})
MATCH (slTs:Slot {name:'ts'})
MATCH (slTempInt:Slot {name:'temperaturaInterna'})
MATCH (slTendencia:Slot {name:'tendencia'})
MATCH (slLCorrida:Slot {name:'corrida'})
MATCH (slLEtapa:Slot {name:'etapa'})
MATCH (slLEstado:Slot {name:'estado'})
MATCH (slUltimaLectura:Slot {name:'ultimaLectura'})
WITH c, LectClass, slLName, slTs, slTempInt, slTendencia, slLCorrida, slLEtapa, slLEstado, slUltimaLectura, etapa, datetime() AS now

MERGE (l:FrameInstance:Lectura {id:'lectura_2025_10_03_04'})-[:INSTANCE_OF]->(LectClass)
MERGE (l)-[lvName:HAS_VALUE {slot:'name'}]->(slLName)
  ON CREATE SET lvName.value = 'Lectura Corrida 2025-10-03 04', lvName.ts = now
  ON MATCH  SET lvName.value = 'Lectura Corrida 2025-10-03 04', lvName.ts = now

MERGE (l)-[lvTs:HAS_VALUE {slot:'ts'}]->(slTs)
  ON CREATE SET lvTs.value = now, lvTs.ts = now
  ON MATCH  SET lvTs.value = now, lvTs.ts = now

// Valores de ejemplo: temperatura y estado
MERGE (l)-[lvTemp:HAS_VALUE {slot:'temperaturaInterna'}]->(slTempInt)
  ON CREATE SET lvTemp.value = 81.0, lvTemp.ts = now
  ON MATCH  SET lvTemp.value = 81.0, lvTemp.ts = now

MERGE (l)-[lvTend:HAS_VALUE {slot:'tendencia'}]->(slTendencia)
  ON CREATE SET lvTend.value = 0, lvTend.ts = now
  ON MATCH  SET lvTend.value = 0, lvTend.ts = now

MERGE (l)-[lvEst:HAS_VALUE {slot:'estado'}]->(slLEstado)
  ON CREATE SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now
  ON MATCH  SET lvEst.value = 'TemperaturaEnRango', lvEst.ts = now

// Referencias: corrida y etapa (valor + relación)
MERGE (l)-[lvCorr:HAS_VALUE {slot:'corrida'}]->(slLCorrida)
  ON CREATE SET lvCorr.value = c.id, lvCorr.ts = now
  ON MATCH  SET lvCorr.value = c.id, lvCorr.ts = now
MERGE (l)-[:DE_CORRIDA {slot:'corrida', ts:now}]->(c)

MERGE (l)-[lvEt:HAS_VALUE {slot:'etapa'}]->(slLEtapa)
  ON CREATE SET lvEt.value = etapa.id, lvEt.ts = now
  ON MATCH  SET lvEt.value = etapa.id, lvEt.ts = now
MERGE (l)-[:EN_ETAPA {slot:'etapa', ts:now}]->(etapa);





//:param corrida_id=>'corrida_2025_10_03_01';
// Verificar el estado actual de la Corrida, Lecturas, Actuadores y Alertas
MATCH (c:Corrida)-[:HAS_VALUE]->(sc:Slot)
OPTIONAL MATCH (l:Lectura)-[:HAS_VALUE]->(sl:Slot)
MATCH (e:Etapa)
MATCH (r:Rango)
MATCH (a:Actuador)-[:HAS_VALUE]->(sa:Slot)
OPTIONAL MATCH (al:Alerta)
OPTIONAL MATCH (reco:Recomendacion)
WHERE c.id = 'corrida_2025_10_03_01'
RETURN c, l, e, r, sc, sl, a, sa, al, reco;


// Modificar la tendencia de la lectura 
MATCH (l:Lectura {id: 'lectura_2025_10_03_01'})-[rTend:HAS_VALUE {slot: 'tendencia'}]->()
SET rTend.value = -1;

// Modificar tendencia de la última lectura de la corrida
MATCH (c:Corrida)-[:ULTIMA_LECTURA]->(l:Lectura)
MATCH (l)-[r:HAS_VALUE {slot: 'tendencia'}]->()
SET r.value = 0.5;






// Actualizar el estado de los actuadores, alertas y recomendaciones para la corrida activa
MATCH (corrida:Corrida)
OPTIONAL MATCH (corrida)-[r:HAS_VALUE {slot: 'fechaFin'}]->()
WHERE r IS NULL OR r.value IS NULL
WITH corrida
MATCH (c:Corrida)-[:ULTIMA_LECTURA]->(l:Lectura)
CALL custom.actualizarEstadoTemperatura(l.id)
CALL custom.actualizarEstadosActuadores(corrida.id)
CALL custom.actualizarAlertas(corrida.id)
CALL custom.actualizarRecomendaciones(corrida.id);