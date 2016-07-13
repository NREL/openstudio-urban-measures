
dirs = Dir.glob("./run/*")

num_failed = 0
dirs.each do |osw_dir|
  ['baseline', 'retrofit'].each do |workflow|
    if File.exists?(File.join(osw_dir, workflow, "run/failed.job"))
      puts "#{osw_dir}/#{workflow} failed to run"
      num_failed += 1
    end
  end
end

puts "#{num_failed} failures"
