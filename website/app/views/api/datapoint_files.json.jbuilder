json.set! :datapoint_id, @datapoint.id.to_s
json.set! :datapoint_files do
	json.array!(@datapoint.datapoint_files) do |file|
	  file.attributes.each do |fk, fv|
	    if fk == '_id'
	      json.set! :id, fv.to_s
	      @file_id = fv.to_s
	    elsif fk == 'uri'
	      json.set! :uri, download_file_datapoint_url(@datapoint.id, file_id: file.id)
	    else
	      json.set! fk, fv
	    end
	  end
	end
end


