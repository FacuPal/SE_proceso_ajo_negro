
Corrida-[TIENE_ETAPA_ACTUAL]->Etapa

-- Configuración de Etapa: Proceso Térmico
ProcesoTermico-[INSTANCIA_DE]->Etapa
Temp80-[INSTANCIA_DE]->Rango
Temp80-[VALOR_ESPERADO]->80
Temp80-[TOLERANCIA]->3
Temp80-[MINIMO]->77
Temp80-[MAXIMO]->83
ProcesoTermico-[CONFIGURA_TEMPERATURA]->Temp80

-- Configuración de Etapa: Enfriamiento
Enfriamiento-[INSTANCIA_DE]->Etapa
Temp30-[INSTANCIA_DE]->Rango
Temp30-[VALOR_ESPERADO]->30
Temp30-[TOLERANCIA]->3
Temp30-[MINIMO]->27
Temp30-[MAXIMO]->33
Enfriamiento-[CONFIGURA_TEMPERATURA]->Temp30

-- Secuencia de Etapas
Corrida-[INICIA_CON]->ProcesoTermico
ProcesoTermico-[PRECEDE_A]->Enfriamiento

-- Corrida
Corrida-[DETECTA]->Estado
Corrida-[DETECTA_ESTADO]->EstadoCalefactor
Corrida-[DETECTA_ESTADO]->EstadoVentilador
Corrida-[TIENE_TEMPERATURA]->TemperaturaInterna
Corrida-[TIENE_ACTUADORES]->Actuadores
TemperaturaInterna-[TIENE_TENDENCIA]->Valor
Lectura-[TIENE_FECHA_HORA]->Ts
Lectura-[PERTENECE_A]->Corrida
Lectura-[REALIZADA_EN_ETAPA]->Etapa
Lectura-[TIENE_VALOR]->TemperaturaInterna

-- Tipos de temperatura
TemperaturaAlta-[TIPO_DE]->Estado
TemperaturaBaja-[TIPO_DE]->Estado
TemperaturaEnRango-[TIPO_DE]->Estado

-- Reglas de temperatura
TemperaturaInterna-[SI_ES]->Menor
Menor-[QUE]->Rango
Menor-[PRODUCE]->TemperaturaBaja

TemperaturaInterna-[SI_ES]->Entre
Entre-[QUE]->Rango
Entre-[PRODUCE]->TemperaturaEnRango

TemperaturaInterna-[SI_ES]->Mayor
Mayor-[QUE]->Rango
Mayor-[PRODUCE]->TemperaturaAlta

-- Modelo de Actuador
Actuador-[TIENE_ESTADO]->EstadoActuador
Actuador-[TIENE_CAPACIDAD]->CapacidadTermica --°C/min 

-- Estados del Actuador
EstadoCalefactor-[TIPO_DE]->EstadoActuador
EstadoVentilador-[TIPO_DE]->EstadoActuador
-- Capacidades del Actuador
CapacidadTermica-[AFECTA]->TemperaturaInterna

-- Instanciación de Calefactor
Calefactor-[INSTANCIA_DE]->Actuador
1-[INSTANCIA_DE]->CapacidadTermica
Calefactor-[TIENE_CAPACIDAD]->1
CalefactorPrendido-[INSTANCIA_DE]->EstadoCalefactor
CalefactorApagado-[INSTANCIA_DE]->EstadoCalefactor

-- Instanciación de Ventilador
Ventilador-[INSTANCIA_DE]->Actuador
(-.5)-[INSTANCIA_DE]->CapacidadTermica
Ventilador-[TIENE_CAPACIDAD]->(-.5)
VentiladorPrendido-[INSTANCIA_DE]->EstadoVentilador
VentiladorApagado-[INSTANCIA_DE]->EstadoVentilador

-- Recomendaciones 
ApagarCalefactor-[TIPO_DE]->Recomendacion
EncenderCalefactor-[TIPO_DE]->Recomendacion
EncenderVentilador-[TIPO_DE]->Recomendacion
ApagarVentilador-[TIPO_DE]->Recomendacion
Mantener-[TIPO_DE]->Recomendacion

Corrida-[RECOMIENDA]->Recomendacion

-- Reglas de control
-- Si temperatura alta y calefactor prendido => ApagarCalefactor
ApagarCalefactor-[REQUIERE]->TemperaturaEnRango
ApagarCalefactor-[REQUIERE]->CalefactorPrendido
ApagarCalefactor-[PRIORIDAD]->10

-- Si temperatura alta y ventilador apagado => EncenderVentilador
EncenderVentilador-[REQUIERE]->TemperaturaAlta
EncenderVentilador-[REQUIERE]->VentiladorApagado
EncenderVentilador-[PRIORIDAD]->9

-- Si temperatura baja y calefactor apagado => EncenderCalefactor
EncenderCalefactor-[REQUIERE]->TemperaturaBaja
EncenderCalefactor-[REQUIERE]->CalefactorApagado
EncenderCalefactor-[PRIORIDAD]->9

-- Si temperatura baja y ventilador prendido => ApagarVentilador
ApagarVentilador-[REQUIERE]->TemperaturaEnRango
ApagarVentilador-[REQUIERE]->VentiladorPrendido
ApagarVentilador-[PRIORIDAD]->8

-- Si temperatura en rango => Mantener (sin cambios)
Mantener-[REQUIERE]->TemperaturaEnRango
Mantener-[PRIORIDAD]->1

-- recomendaciones contradictorias
ApagarCalefactor-[CONFLICTA_CON]->EncenderCalefactor
EncenderCalefactor-[CONFLICTA_CON]->ApagarCalefactor
ApagarVentilador-[CONFLICTA_CON]->EncenderVentilador
EncenderVentilador-[CONFLICTA_CON]->ApagarVentilador
Mantener-[CONFLICTA_CON]->ApagarCalefactor
Mantener-[CONFLICTA_CON]->EncenderCalefactor
Mantener-[CONFLICTA_CON]->ApagarVentilador
Mantener-[CONFLICTA_CON]->EncenderVentilador

