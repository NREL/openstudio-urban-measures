######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

# start the measure
class AddDistrictSystem < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Add district system'
  end

  # human readable description
  def description
    return 'Add district system'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Add district system'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the type of system to add to the building
    systems = OpenStudio::StringVector.new
    systems << 'None'
    systems << 'Community Photovoltaic'
    systems << 'Central Hot and Chilled Water'
    systems << 'Ambient Loop'
    system_type = OpenStudio::Measure::OSArgument.makeChoiceArgument('district_system_type', systems, true)
    system_type.setDisplayName('System Type')
    system_type.setDefaultValue('None')
    system_type.setDescription('Type of central system.')
    args << system_type

    return args
  end

  def add_system_7_commercial(model)
    OpenStudio::Model::OutputVariable.new('Plant System Cycle On Off Status', model)
    OpenStudio::Model::OutputVariable.new('Plant Load Profile Mass Flow Rate', model)
    OpenStudio::Model::OutputVariable.new('Plant Load Profile Heat Transfer Rate', model)
    OpenStudio::Model::OutputVariable.new('Plant Load Profile Heat Transfer Energy', model)
    OpenStudio::Model::OutputVariable.new('Plant Load Profile Heating Energy', model)
    OpenStudio::Model::OutputVariable.new('Plant Load Profile Cooling Energy', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Cooling Demand Rate', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Heating Demand Rate', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Inlet Mass Flow Rate', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Inlet Temperature', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Outlet Temperature', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Not Distributed Demand Rate', model)
    OpenStudio::Model::OutputVariable.new('Plant Supply Side Unmet Demand Rate', model)

    # Hot Water Plant
    hw_t_c = OpenStudio.convert(180, 'F', 'C').get

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    hw_loop.setName('Hot Water Loop')
    hw_sizing_plant = hw_loop.sizingPlant
    hw_sizing_plant.setLoopType('Heating')
    hw_sizing_plant.setDesignLoopExitTemperature(hw_t_c)
    hw_sizing_plant.setLoopDesignTemperatureDifference(11.0)

    hw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    boiler = OpenStudio::Model::BoilerHotWater.new(model)

    boiler_eff_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    boiler_eff_f_of_temp.setName('Boiler Efficiency')
    boiler_eff_f_of_temp.setCoefficient1Constant(1.0)
    boiler_eff_f_of_temp.setInputUnitTypeforX('Dimensionless')
    boiler_eff_f_of_temp.setInputUnitTypeforY('Dimensionless')
    boiler_eff_f_of_temp.setOutputUnitType('Dimensionless')

    boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_f_of_temp)
    boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')

    boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    hw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the hot water loop
    hw_supply_inlet_node = hw_loop.supplyInletNode
    hw_supply_outlet_node = hw_loop.supplyOutletNode
    hw_pump.addToNode(hw_supply_inlet_node)
    hw_loop.addSupplyBranchForComponent(boiler)
    hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
    hw_supply_outlet_pipe.addToNode(hw_supply_outlet_node)

    # Add a setpoint manager to control the
    # hot water to a constant temperature
    hw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    hw_t_sch.setName('HW Temp')
    hw_t_sch.defaultDaySchedule.setName('HW Temp Default')
    hw_t_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hw_t_c)
    hw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hw_t_sch)
    hw_t_stpt_manager.addToNode(hw_supply_outlet_node)

    # Chilled Water Plant
    chw_t_c = OpenStudio.convert(44, 'F', 'C').get

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chw_loop.setName('Chilled Water Loop')
    chw_sizing_plant = chw_loop.sizingPlant
    chw_sizing_plant.setLoopType('Cooling')
    chw_sizing_plant.setDesignLoopExitTemperature(chw_t_c)
    chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)

    chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    chiller = OpenStudio::Model::ChillerElectricEIR.new(model)

    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the chilled water loop
    chw_supply_inlet_node = chw_loop.supplyInletNode
    chw_supply_outlet_node = chw_loop.supplyOutletNode
    chw_pump.addToNode(chw_supply_inlet_node)
    chw_loop.addSupplyBranchForComponent(chiller)
    chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

    # Add a setpoint manager to control the
    # chilled water to a constant temperature
    chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    chw_t_sch.setName('CHW Temp')
    chw_t_sch.defaultDaySchedule.setName('CHW Temp Default')
    chw_t_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), chw_t_c)
    chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_t_sch)
    chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

    schedules = {}
    model.getScheduleFixedIntervals.each do |schedule|
      building = schedule.name.to_s.split[0]
      schedule_name = schedule.name.to_s.split[1..-1].join(' ')
      unless schedules.keys.include? building
        schedules[building] = {}
      end
      schedules[building][schedule_name] = [schedule, schedule.comment.split(' = ')[1].to_f]
    end

    total_heating_capacity = 0
    total_heating_flow_rate = 0
    total_cooling_capacity = 0
    total_cooling_flow_rate = 0
    schedules.each do |building, schedule|
      if schedule['District Heating Hot Water Rate']
        load_profile_plant = OpenStudio::Model::LoadProfilePlant.new(model)
        load_profile_plant.setName("#{building} Heating Load Profile")
        load_profile_plant.setLoadSchedule(schedule['District Heating Hot Water Rate'][0])
        load_profile_plant.setPeakFlowRate(schedule['District Heating Mass Flow Rate'][1])
        load_profile_plant.setFlowRateFractionSchedule(schedule['District Heating Mass Flow Rate'][0])
        hw_loop.addDemandBranchForComponent(load_profile_plant)

        total_heating_capacity += schedule['District Heating Hot Water Rate'][1]
        total_heating_flow_rate += schedule['District Heating Mass Flow Rate'][1]
      end

      if schedule['District Cooling Chilled Water Rate']
        load_profile_plant = OpenStudio::Model::LoadProfilePlant.new(model)
        load_profile_plant.setName("#{building} Cooling Load Profile")
        load_profile_plant.setLoadSchedule(schedule['District Cooling Chilled Water Rate'][0])
        load_profile_plant.setPeakFlowRate(schedule['District Cooling Mass Flow Rate'][1])
        load_profile_plant.setFlowRateFractionSchedule(schedule['District Cooling Mass Flow Rate'][0])
        chw_loop.addDemandBranchForComponent(load_profile_plant)

        total_cooling_capacity += schedule['District Cooling Chilled Water Rate'][1]
        total_cooling_flow_rate += schedule['District Cooling Mass Flow Rate'][1]
      end
    end

    # sizing is occuring on design days which might not have maximum load, hard size equipment here
    if total_heating_capacity > 0
      boiler.setNominalCapacity(1.2 * total_heating_capacity)
      boiler.setDesignWaterFlowRate(total_heating_flow_rate)
    end

    if total_cooling_capacity > 0
      chiller.setReferenceCapacity(1.2 * total_cooling_capacity)
      chiller.setReferenceChilledWaterFlowRate(total_cooling_flow_rate)
    end
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    system_type = runner.getStringArgumentValue('district_system_type', user_arguments)

    if system_type == 'None'
      runner.registerAsNotApplicable('NA.')
    elsif system_type == 'Community Photovoltaic'
      # already done?
    elsif system_type == 'Central Hot and Chilled Water'
      # TODO: check commercial vs residential
      add_system_7_commercial(model)
    elsif system_type == 'Ambient Loop'
      # todo
    end

    return true
  end
end

# register the measure to be used by the application
AddDistrictSystem.new.registerWithApplication
