// Constraints / Indexes
CREATE CONSTRAINT frame_class_constraint IF NOT EXISTS FOR (c:FrameClass) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT frame_instance_constraint IF NOT EXISTS FOR (i:FrameInstance) REQUIRE i.id IS UNIQUE;
CREATE CONSTRAINT slot_constraint IF NOT EXISTS FOR (s:Slot) REQUIRE s.name IS UNIQUE;
CREATE INDEX daemon_index IF NOT EXISTS FOR (d:Daemon) ON (d.name);

// ===================== Clases (FrameClass) =====================
MERGE (Rango:FrameClass {name:'Rango'})
MERGE (Etapa:FrameClass {name:'Etapa'})
MERGE (Temperatura:FrameClass {name:'Temperatura'})
MERGE (Corrida:FrameClass {name:'Corrida'})

// ===================== Slots (globales por nombre) =====================
// Rango
MERGE (slName:Slot {name:'name'})
MERGE (slValorEsperado:Slot {name:'valorEsperado'})
MERGE (slTolerancia:Slot {name:'tolerancia'})
MERGE (slMinimo:Slot {name:'minimo'})
MERGE (slMaximo:Slot {name:'maximo'})
// Etapa
MERGE (slPrecedeA:Slot {name:'precedeA'})
MERGE (slConfigTemp:Slot {name:'configuracionTemperatura'})
// Temperatura
MERGE (slValor:Slot {name:'valor'})
MERGE (slTS:Slot {name:'ts'})
MERGE (slUnidad:Slot {name:'unidad'})
MERGE (slEstado:Slot {name:'estado'})
// Corrida
MERGE (slId:Slot {name:'id'})
MERGE (slFechaInicio:Slot {name:'fechaInicio'})
MERGE (slEtapaActual:Slot {name:'etapaActual'})
MERGE (slFechaFin:Slot {name:'fechaFin'})
MERGE (slTempInterna:Slot {name:'temperaturaInterna'})

// ===================== Declaración de Slots por Clase =====================
// Rango HAS_SLOT + defaults
MERGE (Rango)-[:HAS_SLOT {type:'string', cardinality:'1', required:true}]->(slName)
MERGE (Rango)-[:HAS_SLOT {type:'float',  cardinality:'1', required:true}]->(slValorEsperado)
MERGE (Rango)-[:HAS_SLOT {type:'float',  cardinality:'1', required:true}]->(slTolerancia)
MERGE (Rango)-[:HAS_SLOT {type:'float',  cardinality:'1', required:true}]->(slMinimo)
MERGE (Rango)-[:HAS_SLOT {type:'float',  cardinality:'1', required:true}]->(slMaximo)

// Etapa HAS_SLOT
MERGE (Etapa)-[:HAS_SLOT {type:'string', cardinality:'1',   required:true}]->(slName)
MERGE (Etapa)-[:HAS_SLOT {type:'Etapa',  cardinality:'0..1', required:false}]->(slPrecedeA)
MERGE (Etapa)-[:HAS_SLOT {type:'Rango',  cardinality:'1',   required:true}]->(slConfigTemp)

// Temperatura HAS_SLOT + defaults
MERGE (Temperatura)-[:HAS_SLOT {type:'string',     cardinality:'1', required:true}]->(slName)
MERGE (Temperatura)-[:HAS_SLOT {type:'float',      cardinality:'1', required:true}]->(slValor)
MERGE (Temperatura)-[:HAS_SLOT {type:'datetime',   cardinality:'1', required:true}]->(slTS)
MERGE (Temperatura)-[:HAS_SLOT {type:'string',     cardinality:'1', required:true}]->(slUnidad)
MERGE (Temperatura)-[:HAS_SLOT {type:'enum',       cardinality:'1', required:true, enum:['TemperaturaBaja','TemperaturaAlta','TemperaturaEnRango']}]->(slEstado)
MERGE (Temperatura)-[defTName:DEFAULT {value:'Temperatura Interna'}]->(slName)
  ON CREATE SET defTName.ts = datetime(), defTName.source='seed'
  ON MATCH  SET defTName.ts = datetime()
MERGE (Temperatura)-[defTUnidad:DEFAULT {value:'Celsius'}]->(slUnidad)
  ON CREATE SET defTUnidad.ts = datetime(), defTUnidad.source='seed'
  ON MATCH  SET defTUnidad.ts = datetime()
MERGE (Temperatura)-[defTEstado:DEFAULT {value:'TemperaturaEnRango'}]->(slEstado)
  ON CREATE SET defTEstado.ts = datetime(), defTEstado.source='seed'
  ON MATCH  SET defTEstado.ts = datetime()

// Corrida HAS_SLOT + defaults
MERGE (Corrida)-[:HAS_SLOT {type:'string',    cardinality:'1',   required:true}]->(slName)
MERGE (Corrida)-[:HAS_SLOT {type:'integer',   cardinality:'1',   required:true}]->(slId)
MERGE (Corrida)-[:HAS_SLOT {type:'date',      cardinality:'0..1', required:true}]->(slFechaInicio)
MERGE (Corrida)-[:HAS_SLOT {type:'Etapa',     cardinality:'1',   required:true}]->(slEtapaActual)
MERGE (Corrida)-[:HAS_SLOT {type:'date',      cardinality:'0..1', required:false}]->(slFechaFin)
MERGE (Corrida)-[:HAS_SLOT {type:'Temperatura', cardinality:'1', required:true}]->(slTempInterna)
MERGE (Corrida)-[defCIni:DEFAULT {value:'now'}]->(slFechaInicio)
  ON CREATE SET defCIni.ts = datetime(), defCIni.source='seed'
  ON MATCH  SET defCIni.ts = datetime()
MERGE (Corrida)-[defCEtapa:DEFAULT {value:'proceso_termico'}]->(slEtapaActual)
  ON CREATE SET defCEtapa.ts = datetime(), defCEtapa.source='seed'
  ON MATCH  SET defCEtapa.ts = datetime()

// ===================== Demonios =====================
MERGE (dActMinMax:Daemon {name:'actualizarMinimoMaximo'})
MERGE (dGetMin:Daemon    {name:'getMinimo'})
MERGE (dGetMax:Daemon    {name:'getMaximo'})
MERGE (dUpdEstadoTemp:Daemon {name:'actualizarEstadoTemperatura'})

// Enlaces Slot -> Daemon
MERGE (slValorEsperado)-[ModificaValor:IF_MODIFIED]->(dActMinMax)
  ON CREATE SET ModificaValor.ts = datetime(), ModificaValor.source='seed'
  ON MATCH  SET ModificaValor.ts = datetime()
MERGE (slTolerancia)-[ModificaTolerancia:IF_MODIFIED]->(dActMinMax)
  ON CREATE SET ModificaTolerancia.ts = datetime(), ModificaTolerancia.source='seed'
  ON MATCH  SET ModificaTolerancia.ts = datetime()
MERGE (slMinimo)-[NecesitaMinimo:IF_NEEDED ]->(dGetMin)
  ON CREATE SET NecesitaMinimo.ts = datetime(), NecesitaMinimo.source='seed'
  ON MATCH  SET NecesitaMinimo.ts = datetime()
MERGE (slMaximo)-[NecesitaMaximo:IF_NEEDED ]->(dGetMax)
  ON CREATE SET NecesitaMaximo.ts = datetime(), NecesitaMaximo.source='seed'
  ON MATCH  SET NecesitaMaximo.ts = datetime()
MERGE (slValor)-[AgregaValor:IF_ADDED  ]->(dUpdEstadoTemp)
  ON CREATE SET AgregaValor.ts = datetime(), AgregaValor.source='seed'
  ON MATCH  SET AgregaValor.ts = datetime()
MERGE (slEtapaActual)-[ModificaEtapa:IF_MODIFIED]->(dUpdEstadoTemp)
  ON CREATE SET ModificaEtapa.ts = datetime(), ModificaEtapa.source='seed'
  ON MATCH  SET ModificaEtapa.ts = datetime()

MERGE (dActMinMax)-[:UPDATES]->(slMaximo)
MERGE (dActMinMax)-[:UPDATES]->(slMinimo)
MERGE (dUpdEstadoTemp)-[:UPDATES]->(slEstado)

// ===================== Instancias (FrameInst) =====================
// Rango: Temp80 / Temp30
MERGE (temp80:FrameInstance:Rango {id:'temp80'})-[:INSTANCE_OF {name: 'Temp80 es Rango'}]->(Rango)
MERGE (temp80)-[:HAS_VALUE {slot: 'name', value:'Rango de temperatura para proceso térmico', ts: datetime()}]->(slName)
MERGE (temp80)-[:HAS_VALUE {slot: 'valorEsperado', value:80.0, ts: datetime()}]->(slValorEsperado)
MERGE (temp80)-[:HAS_VALUE {slot: 'tolerancia', value:3.0, ts: datetime()}]->(slTolerancia)
MERGE (temp80)-[:HAS_VALUE {slot: 'minimo', value:77.0, ts: datetime()}]->(slMinimo)
MERGE (temp80)-[:HAS_VALUE {slot: 'maximo', value:83.0, ts: datetime()}]->(slMaximo)
  
MERGE (temp30:FrameInstance:Rango {id:'temp30'})-[:INSTANCE_OF {name: 'Temp30 es Rango'}]->(Rango)
MERGE (temp30)-[:HAS_VALUE {slot: 'name', value:'Rango de temperatura para enfriamiento', ts: datetime()}]->(slName)
MERGE (temp30)-[:HAS_VALUE {slot: 'valorEsperado', value:30.0, ts: datetime()}]->(slValorEsperado)
MERGE (temp30)-[:HAS_VALUE {slot: 'tolerancia', value:3.0, ts: datetime()}]->(slTolerancia)
MERGE (temp30)-[:HAS_VALUE {slot: 'minimo', value:27.0, ts: datetime()}]->(slMinimo)
MERGE (temp30)-[:HAS_VALUE {slot: 'maximo', value:33.0, ts: datetime()}]->(slMaximo)

// Etapa: ProcesoTermico / Enfriamiento
MERGE (enf:FrameInstance:Etapa {id:'enfriamiento'})-[:INSTANCE_OF]->(Etapa)
MERGE (enf)-[:HAS_VALUE {slot: 'name', value:'Enfriamiento', ts: datetime()}]->(slName)
MERGE (enf)-[:HAS_VALUE {slot: 'configuracionTemperatura', value:'Temp30', ts: datetime()}]->(slConfigTemp)
MERGE (enf)-[:CONFIGURACION_TEMPERATURA {slot:'configuracionTemperatura', ts: datetime()}]->(temp30)

MERGE (procT:FrameInstance:Etapa {id:'proceso_termico'})-[:INSTANCE_OF]->(Etapa)
MERGE (procT)-[:HAS_VALUE {slot: 'name', value:'Proceso Térmico', ts: datetime()}]->(slName)
MERGE (procT)-[:HAS_VALUE {slot: 'configuracionTemperatura', value:'Temp80', ts: datetime()}]->(slConfigTemp)
MERGE (procT)-[:CONFIGURACION_TEMPERATURA {slot:'configuracionTemperatura', ts: datetime()}]->(temp80)
MERGE (procT)-[:HAS_VALUE {slot: 'precedeA', value:'enfriamiento', ts: datetime()}]->(slPrecedeA)
MERGE (procT)-[:PRECEDE_A {slot:'precedeA', ts: datetime()}]->(enf)


// Corrida: Corrida1
MERGE (corrida1:FrameInstance:Corrida {id:'1'})-[:INSTANCE_OF]->(Corrida)
MERGE (corrida1)-[:HAS_VALUE {slot: 'name', value:'Corrida de prueba 1', ts: datetime()}]->(slName)
MERGE (corrida1)-[:HAS_VALUE {slot: 'id', value:1, ts: datetime()}]->(slId)
MERGE (corrida1)-[:HAS_VALUE {slot: 'fechaInicio', value:date('2023-10-01'), ts: datetime()}]->(slFechaInicio)
MERGE (corrida1)-[:HAS_VALUE {slot: 'etapaActual', value:'proceso_termico', ts: datetime()}]->(slEtapaActual)
MERGE (corrida1)-[:ETAPA_ACTUAL {name: 'Etapa Actual de la corrida'}]->(procT)

MERGE (temp1:FrameInstance:Temperatura {id:'temp_interna_corrida1'})-[:INSTANCE_OF]->(Temperatura)
MERGE (temp1)-[:HAS_VALUE {slot: 'name', value:'Temperatura Interna', ts: datetime()}]->(slName)
MERGE (temp1)-[:HAS_VALUE {slot: 'valor', value:82.0, ts: datetime()}]->(slValor)
MERGE (temp1)-[:HAS_VALUE {slot: 'ts', value:datetime('2023-10-01T10:00:00'), ts: datetime()}]->(slTS)
MERGE (temp1)-[:HAS_VALUE {slot: 'unidad', value:'Celsius', ts: datetime()}]->(slUnidad)
MERGE (temp1)-[:HAS_VALUE {slot: 'estado', value:'TemperaturaEnRango', ts: datetime()}]->(slEstado)
MERGE (corrida1)-[:HAS_VALUE {slot: 'temperaturaInterna', value:'temp_interna_corrida1', ts: datetime()}]->(slTempInterna)
MERGE (corrida1)-[:TIENE_TEMPERATURA {slot: 'temperaturaInterna', ts: datetime()}]->(temp1)

MERGE (corrida2:FrameInstance:Corrida {id:'2'})-[:INSTANCE_OF]->(Corrida)
MERGE (corrida2)-[:HAS_VALUE {slot: 'name', value:'Corrida de prueba 2', ts: datetime()}]->(slName)
MERGE (corrida2)-[:HAS_VALUE {slot: 'id', value:2, ts: datetime()}]->(slId)
MERGE (corrida2)-[:HAS_VALUE {slot: 'fechaInicio', value:date('2023-10-01'), ts: datetime()}]->(slFechaInicio)
MERGE (corrida2)-[:HAS_VALUE {slot: 'etapaActual', value:'proceso_termico', ts: datetime()}]->(slEtapaActual)
MERGE (corrida2)-[:ETAPA_ACTUAL {name: 'Etapa Actual de la corrida'}]->(procT)

MERGE (temp2:FrameInstance:Temperatura {id:'temp_interna_corrida2'})-[:INSTANCE_OF]->(Temperatura)
MERGE (temp2)-[:HAS_VALUE {slot: 'name', value:'Temperatura Interna', ts: datetime()}]->(slName)
MERGE (temp2)-[:HAS_VALUE {slot: 'valor', value:75.0, ts: datetime()}]->(slValor)
MERGE (temp2)-[:HAS_VALUE {slot: 'ts', value:datetime('2023-10-01T10:00:00'), ts: datetime()}]->(slTS)
MERGE (temp2)-[:HAS_VALUE {slot: 'unidad', value:'Celsius', ts: datetime()}]->(slUnidad)
MERGE (temp2)-[:HAS_VALUE {slot: 'estado', value:'TemperaturaBaja', ts: datetime()}]->(slEstado)
MERGE (corrida2)-[:HAS_VALUE {slot: 'temperaturaInterna', value:'temp_interna_corrida2', ts: datetime()}]->(slTempInterna)
MERGE (corrida2)-[:TIENE_TEMPERATURA {slot: 'temperaturaInterna', ts: datetime()}]->(temp2)


MERGE (corrida3:FrameInstance:Corrida {id:'3'})-[:INSTANCE_OF]->(Corrida)
MERGE (corrida3)-[:HAS_VALUE {slot: 'name', value:'Corrida de prueba 3', ts: datetime()}]->(slName)
MERGE (corrida3)-[:HAS_VALUE {slot: 'id', value:3, ts: datetime()}]->(slId)
MERGE (corrida3)-[:HAS_VALUE {slot: 'fechaInicio', value:date('2023-10-01'), ts: datetime()}]->(slFechaInicio)
MERGE (corrida3)-[:HAS_VALUE {slot: 'etapaActual', value:'proceso_termico', ts: datetime()}]->(slEtapaActual)
MERGE (corrida3)-[:ETAPA_ACTUAL {name: 'Etapa Actual de la corrida'}]->(procT)

MERGE (temp3:FrameInstance:Temperatura {id:'temp_interna_corrida3'})-[:INSTANCE_OF]->(Temperatura)
MERGE (temp3)-[:HAS_VALUE {slot: 'name', value:'Temperatura Interna', ts: datetime()}]->(slName)
MERGE (temp3)-[:HAS_VALUE {slot: 'valor', value:88.0, ts: datetime()}]->(slValor)
MERGE (temp3)-[:HAS_VALUE {slot: 'ts', value:datetime('2023-10-01T10:00:00'), ts: datetime()}]->(slTS)
MERGE (temp3)-[:HAS_VALUE {slot: 'unidad', value:'Celsius', ts: datetime()}]->(slUnidad)
MERGE (temp3)-[:HAS_VALUE {slot: 'estado', value:'TemperaturaAlta', ts: datetime()}]->(slEstado)
MERGE (corrida3)-[:HAS_VALUE {slot: 'temperaturaInterna', value:'temp_interna_corrida3', ts: datetime()}]->(slTempInterna)
MERGE (corrida3)-[:TIENE_TEMPERATURA {slot: 'temperaturaInterna', ts: datetime()}]->(temp3)

// ===================== Triggers =====================
// Borrar triggers existentes (si los hay)
CALL apoc.trigger.removeAll();

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
    CALL apoc.log.info('actMinMax: rel=' + toString(id(rel)))
    CALL apoc.log.info('actMinMax: key=' + toString(key))
    CALL apoc.log.info('actMinMax: old=' + toString(old))
    CALL apoc.log.info('actMinMax: new=' + toString(new))


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

    CALL apoc.log.info('nuevoMin: ' + toString(nuevoMin))
    CALL apoc.log.info('nuevoMax: ' + toString(nuevoMax))

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

// MERGE (slEtapaActual)  -[ModificaEtapa:IF_MODIFIED]->(dUpdEstadoTemp)
//   ON CREATE SET ModificaEtapa.ts = datetime(), ModificaEtapa.source='seed'
//   ON MATCH  SET ModificaEtapa.ts = datetime()
// Trigger para actualizar el estado de la temperatura al cambiar la etapa actual en una Corrida
// Trigger para crear la relación :ETAPA_ACTUAL cuando se modifica el valor del slot de la corrida
CALL apoc.trigger.add('actualizarEtapaActual',
  "
    // Obtenemos los cambios en las relaciones verificando la existencia de los cambios
    UNWIND coalesce($assignedRelationshipProperties.value, {}) AS chg
    WITH chg
    WHERE chg IS NOT NULL 
    UNWIND coalesce(chg, {}) AS chgRel
    //
    WITH chgRel.relationship AS rel, chgRel.key AS key, coalesce(chgRel.old, 0) AS old, chgRel.new AS new
    WHERE new IS NOT NULL AND key = 'value' AND type(rel) = 'HAS_VALUE' AND rel.slot IN ['etapaActual']
    CALL apoc.log.info('actEtapaActual: rel=' + toString(id(rel)))
    CALL apoc.log.info('actEtapaActual: key=' + toString(key))
    CALL apoc.log.info('actEtapaActual: old=' + toString(old))
    CALL apoc.log.info('actEtapaActual: new=' + toString(new))

    // Instancia de :Corrida afectada
    WITH DISTINCT startNode(rel) AS corridaNode, new AS nuevaEtapaId
    WHERE corridaNode:Corrida

    CALL apoc.log.info('actEtapaActual: corridaNode=' + toString(id(corridaNode)))
    CALL apoc.log.info('actEtapaActual: nuevaEtapaId=' + toString(nuevaEtapaId))

    // Buscar la instancia de Etapa correspondiente
    MATCH (etapaNode:FrameInstance:Etapa {id: nuevaEtapaId})
    
    // // Eliminar relación ETAPA_ACTUAL anterior si existe
    // OPTIONAL MATCH (corridaNode)-[oldRel:ETAPA_ACTUAL]->(:FrameInstance:Etapa) 
    // WITH oldRel, corridaNode, etapaNode
    // WHERE id(oldRel) IS NOT NULL
    // DELETE oldRel
    
    WITH corridaNode, etapaNode
    CALL apoc.log.info('Por crear la nueva relacion')
    // Crear nueva relación ETAPA_ACTUAL
    MERGE (corridaNode)-[newRel:ETAPA_ACTUAL {name: 'Etapa Actual de la corrida'}]->(etapaNode)
      ON CREATE SET newRel.ts = datetime(), newRel.source = 'trigger_actualizarEstadoTemperatura'
      ON MATCH SET newRel.ts = datetime(), newRel.source = 'trigger_actualizarEstadoTemperatura'
",{phase:'after'});
