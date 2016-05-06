module OsLib_Schedules

  # create a ruleset schedule with a basic profile
  def OsLib_Schedules.createSimpleSchedule(model, options = {})

    defaults = {
        "name" => nil,
        "winterTimeValuePairs" => {24.0 => 0.0},
        "summerTimeValuePairs" => {24.0 => 1.0},
        "defaultTimeValuePairs" => {24.0 => 1.0},
    }

    # merge user inputs with defaults
    options = defaults.merge(options)

    #ScheduleRuleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    if name
      sch_ruleset.setName(options["name"])
    end

    #Winter Design Day
    winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
    winter_dsn_day = sch_ruleset.winterDesignDaySchedule
    winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
    options["winterTimeValuePairs"].each do |k,v|
      hour = k.truncate
      min = ((k - hour)*60).to_i
      winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0),v)
    end

    #Summer Design Day
    summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
    summer_dsn_day = sch_ruleset.summerDesignDaySchedule
    summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
    options["summerTimeValuePairs"].each do |k,v|
      hour = k.truncate
      min = ((k - hour)*60).to_i
      summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0),v)
    end

    #All Days
    default_day = sch_ruleset.defaultDaySchedule
    default_day.setName("#{sch_ruleset.name} Schedule Week Day")
    options["defaultTimeValuePairs"].each do |k,v|
      hour = k.truncate
      min = ((k - hour)*60).to_i
      default_day.addValue(OpenStudio::Time.new(0, hour, min, 0),v)
    end

    result = sch_ruleset
    return result

  end #end of OsLib_Schedules.createSimpleSchedule

  # find the maximum profile value for a schedule
  def OsLib_Schedules.getMinMaxAnnualProfileValue(model, schedule)

    # gather profiles
    profiles = []
    defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
    profiles << defaultProfile
    rules = schedule.scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    # test profiles
    min = nil
    max = nil
    profiles.each do |profile|
      profile.values.each do |value|
        if min.nil?
          min = value
        else
          if min > value then min = value end
        end
        if max.nil?
          max = value
        else
          if max < value then max = value end
        end
      end
    end

    result = {"min" => min, "max" => max} # this doesn't include summer and winter design day
    return result

  end #end of OsLib_Schedules.getMaxAnnualProfileValue

  # find the maximum profile value for a schedule
  def OsLib_Schedules.simpleScheduleValueAdjust(model,schedule,double, modificationType = "Multiplier")# can increase/decrease by percentage or static value

    # todo - add in design days, maybe as optional argument

    # give option to clone or not

    # gather profiles
    profiles = []
    defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
    profiles << defaultProfile
    rules = schedule.scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    # alter profiles
    profiles.each do |profile|
      times = profile.times
      i = 0
      profile.values.each do |value|
        if modificationType == "Multiplier" or modificationType == "Percentage" # percentage was used early on but Multiplier is preferable
          profile.addValue(times[i],value*double)
        end
        if modificationType == "Sum" or modificationType == "Value" # value was used early on but Sum is preferable
          profile.addValue(times[i],value+double)
        end
        i += 1
      end
    end

    result = schedule
    return result

  end #end of OsLib_Schedules.getMaxAnnualProfileValue

  # find the maximum profile value for a schedule
  def OsLib_Schedules.conditionalScheduleValueAdjust(model,schedule,valueTestDouble,passDouble,failDouble, floorDouble,modificationType = "Multiplier")# can increase/decrease by percentage or static value

    # todo - add in design days, maybe as optional argument

    # give option to clone or not

    # gather profiles
    profiles = []
    defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
    profiles << defaultProfile
    rules = schedule.scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    # alter profiles
    profiles.each do |profile|
      times = profile.times
      i = 0

      profile.values.each do |value|

        # run test on this value
        if value < valueTestDouble
          double = passDouble
        else
          double = failDouble
        end

        # skip if value is floor or less
        next if value <= floorDouble

        if modificationType == "Multiplier"
          profile.addValue(times[i],[value*double,floorDouble].max) #take the max of the floor or resulting value
        end
        if modificationType == "Sum"
          profile.addValue(times[i],[value+double,floorDouble].max) #take the max of the floor or resulting value
        end
        i += 1

      end
    end

    result = schedule
    return result

  end #end of OsLib_Schedules.getMaxAnnualProfileValue

  # merge multiple schedules into one using load or other value to weight each schedules influence on the merge
  def OsLib_Schedules.weightedMergeScheduleRulesets(model, scheduleWeighHash)

    # WARNING NOT READY FOR GENERAL USE YET - this doesn't do anything with rules yet, just winter, summer, and default profile

    # get denominator for weight
    denominator = 0
    scheduleWeighHash.each do |schedule,weight|
      denominator += weight
    end

    # create new schedule
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    sch_ruleset.setName("Merged Schedule") # todo - make this optional user argument

    # create winter design day profile
    winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
    winter_dsn_day = sch_ruleset.winterDesignDaySchedule
    winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")

    # create  summer design day profile
    summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
    summer_dsn_day = sch_ruleset.summerDesignDaySchedule
    summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")

    # create default profile
    default_day = sch_ruleset.defaultDaySchedule
    default_day.setName("#{sch_ruleset.name} Schedule Week Day")

    # hash of schedule rules
    rulesHash = {} # mon, tue, wed, thur, fri, sat, sun, startDate, endDate
    # to avoid stacking order issues across schedules, I may need to make a rule for each day of the week for each date range

    scheduleWeighHash.each do |schedule,weight|

      # populate winter design day profile
      oldWinterProfile = schedule.to_ScheduleRuleset.get.winterDesignDaySchedule
      times_final = summer_dsn_day.times
      i = 0
      valueUpdatedArray = []
      # loop through times already in profile and update values
      until i > times_final.size - 1
        value = oldWinterProfile.getValue(times_final[i])*weight/denominator
        starting_value = winter_dsn_day.getValue(times_final[i])
        winter_dsn_day.addValue(times_final[i],value + starting_value)
        valueUpdatedArray << times_final[i]
        i += 1
      end
      # loop through any new times unique to the current old profile to be merged
      j = 0
      times = oldWinterProfile.times
      values = oldWinterProfile.values
      until j > times.size - 1
        if not valueUpdatedArray.include? times[j]
          value = values[j]*weight/denominator
          starting_value = winter_dsn_day.getValue(times[j])
          winter_dsn_day.addValue(times[j],value+starting_value)
        end
        j += 1
      end

      # populate summer design day profile
      oldSummerProfile = schedule.to_ScheduleRuleset.get.summerDesignDaySchedule
      times_final = summer_dsn_day.times
      i = 0
      valueUpdatedArray = []
      # loop through times already in profile and update values
      until i > times_final.size - 1
        value = oldSummerProfile.getValue(times_final[i])*weight/denominator
        starting_value = summer_dsn_day.getValue(times_final[i])
        summer_dsn_day.addValue(times_final[i],value + starting_value)
        valueUpdatedArray << times_final[i]
        i += 1
      end
      # loop through any new times unique to the current old profile to be merged
      j = 0
      times = oldSummerProfile.times
      values = oldSummerProfile.values
      until j > times.size - 1
        if not valueUpdatedArray.include? times[j]
          value = values[j]*weight/denominator
          starting_value = summer_dsn_day.getValue(times[j])
          summer_dsn_day.addValue(times[j],value+starting_value)
        end
        j += 1
      end

      # populate default profile
      oldDefaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
      times_final = default_day.times
      i = 0
      valueUpdatedArray = []
      # loop through times already in profile and update values
      until i > times_final.size - 1
        value = oldDefaultProfile.getValue(times_final[i])*weight/denominator
        starting_value = default_day.getValue(times_final[i])
        default_day.addValue(times_final[i],value + starting_value)
        valueUpdatedArray << times_final[i]
        i += 1
      end
      # loop through any new times unique to the current old profile to be merged
      j = 0
      times = oldDefaultProfile.times
      values = oldDefaultProfile.values
      until j > times.size - 1
        if not valueUpdatedArray.include? times[j]
          value = values[j]*weight/denominator
          starting_value = default_day.getValue(times[j])
          default_day.addValue(times[j],value+starting_value)
        end
        j += 1
      end

      # create rules

      # gather data for rule profiles

      # populate rule profiles

    end

    result = {"mergedSchedule" => sch_ruleset, "denominator" => denominator}
    return result

  end #end of OsLib_Schedules.weightedMergeScheduleRulesets

  # create a new schedule using absolute velocity of existing schedule
  def OsLib_Schedules.scheduleFromRateOfChange(model, schedule)

    # clone source schedule
    newSchedule = schedule.clone(model)
    newSchedule.setName("#{schedule.name} - Rate of Change")
    newSchedule = newSchedule.to_ScheduleRuleset.get

    # create array of all profiles to change. This includes summer, winter, default, and rules
    profiles = []
    profiles << newSchedule.winterDesignDaySchedule
    profiles << newSchedule.summerDesignDaySchedule
    profiles << newSchedule.defaultDaySchedule

    # time values may need
    endProfileTime = OpenStudio::Time.new(0, 24, 0, 0)
    hourBumpTime = OpenStudio::Time.new(0, 1, 0, 0)
    oneHourLeftTime = OpenStudio::Time.new(0, 23, 0, 0)

    rules = newSchedule.scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    profiles.uniq.each do |profile|
      times = profile.times
      values = profile.values

      i = 0
      valuesIntermediate = []
      timesIntermediate = []
      until i == (values.size)
        if i == 0
          valuesIntermediate << 0.0
          if times[i] > hourBumpTime
            timesIntermediate << times[i] - hourBumpTime
            if times[i+1].nil?
              timeStepValue = endProfileTime.hours + endProfileTime.minutes/60 - times[i].hours - times[i].minutes/60
            else
              timeStepValue = times[i+1].hours + times[i+1].minutes/60 - times[i].hours - times[i].minutes/60
            end
            valuesIntermediate << (values[i+1].to_f - values[i].to_f ).abs/(timeStepValue*2)
          end
          timesIntermediate << times[i]
        elsif i == (values.size - 1)
          if times[times.size - 2] < oneHourLeftTime
            timesIntermediate << times[times.size - 2] +  hourBumpTime# this should be the second to last time
            timeStepValue = times[i-1].hours + times[i-1].minutes/60 - times[i-2].hours - times[i-2].minutes/60
            valuesIntermediate << (values[i-1].to_f - values[i-2].to_f ).abs/(timeStepValue*2)
          end
          valuesIntermediate << 0.0
          timesIntermediate << times[i] # this should be the last time
        else
          # get value multiplier based on how many hours it is spread over
          timeStepValue = times[i].hours + times[i].minutes/60 - times[i-1].hours - times[i-1].minutes/60
          valuesIntermediate << (values[i].to_f - values[i - 1].to_f ).abs/timeStepValue
          timesIntermediate << times[i]
        end
        i += 1
      end

      # delete all profile values
      profile.clearValues

      i = 0
      until i == (timesIntermediate.size)
        if i == (timesIntermediate.size - 1)
          profile.addValue(timesIntermediate[i],valuesIntermediate[i].to_f)
        else
          profile.addValue(timesIntermediate[i],valuesIntermediate[i].to_f)
        end
        i += 1
      end

    end

    # fix velocity so it isn't fraction change per step, but per hour (I need to count hours between times and divide value by this)

    result = newSchedule
    return result

  end #end of OsLib_Schedules.createSimpleSchedule

  # create a complex ruleset schedule
  def OsLib_Schedules.createComplexSchedule(model, options = {})

    defaults = {
        "name" => nil,
        "default_day" => ["always_on",[24.0,1.0]]
    }

    # merge user inputs with defaults
    options = defaults.merge(options)

    #ScheduleRuleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    if name
      sch_ruleset.setName(options["name"])
    end

    #Winter Design Day
    unless options["winter_design_day"].nil?
      winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
      winter_dsn_day = sch_ruleset.winterDesignDaySchedule
      winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
      options["winter_design_day"].each do |data_pair|
        hour = data_pair[0].truncate
        min = ((data_pair[0] - hour)*60).to_i
        winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0),data_pair[1])
      end
    end

    #Summer Design Day
    unless options["summer_design_day"].nil?
      summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
      summer_dsn_day = sch_ruleset.summerDesignDaySchedule
      summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
      options["summer_design_day"].each do |data_pair|
        hour = data_pair[0].truncate
        min = ((data_pair[0] - hour)*60).to_i
        summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0),data_pair[1])
      end
    end

    #Default Day
    default_day = sch_ruleset.defaultDaySchedule
    default_day.setName("#{sch_ruleset.name} #{options["default_day"][0]}")
    default_data_array = options["default_day"]
    default_data_array.delete_at(0)
    default_data_array.each do |data_pair|
      hour = data_pair[0].truncate
      min = ((data_pair[0] - hour)*60).to_i
      default_day.addValue(OpenStudio::Time.new(0, hour, min, 0),data_pair[1])
    end

    #Rules
    unless options["rules"].nil?
      options["rules"].each do |data_array|
        rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        rule.setName("#{sch_ruleset.name} #{data_array[0]} Rule")
        date_range = data_array[1].split("-")
        start_date = date_range[0].split("/")
        end_date = date_range[1].split("/")
        rule.setStartDate(model.getYearDescription.makeDate(start_date[0].to_i,start_date[1].to_i))
        rule.setEndDate(model.getYearDescription.makeDate(end_date[0].to_i,end_date[1].to_i))
        days = data_array[2].split("/")
        rule.setApplySunday(true) if days.include? "Sun"
        rule.setApplyMonday(true) if days.include? "Mon"
        rule.setApplyTuesday(true) if days.include? "Tue"
        rule.setApplyWednesday(true) if days.include? "Wed"
        rule.setApplyThursday(true) if days.include? "Thu"
        rule.setApplyFriday(true) if days.include? "Fri"
        rule.setApplySaturday(true) if days.include? "Sat"
        day_schedule = rule.daySchedule
        day_schedule.setName("#{sch_ruleset.name} #{data_array[0]}")
        data_array.delete_at(0)
        data_array.delete_at(0)
        data_array.delete_at(0)
        data_array.each do |data_pair|
          hour = data_pair[0].truncate
          min = ((data_pair[0] - hour)*60).to_i
          day_schedule.addValue(OpenStudio::Time.new(0, hour, min, 0),data_pair[1])
        end
      end
    end

    result = sch_ruleset
    return result

  end #end of OsLib_Schedules.createComplexSchedule

end