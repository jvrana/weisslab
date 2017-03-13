needs "aqualib/lib/standard"
needs "aqualib/lib/cloning"

class Protocol

  include Standard
  include Cloning

  def arguments
    {
      io_hash: {},
      #Enter the fragment sample ids as array of arrays, eg [[2058,2059],[2060,2061],[2058,2062]]
      Plasmids: [[1, 2], [1, 2]],
      #Tell the system if the ids you entered are sample ids or item ids by enter sample or item, sample is the default option in the protocol.
      sample_or_item: "sample",
      #Enter correspoding plasmid id or fragment id for each fragment to be Gibsoned in.
      "CHO_strain_ids CHO Strain" => [3,4],
      debug_mode: "Yes",
    }
  end


  def main
    io_hash = input[:io_hash]
    io_hash = input if !input[:io_hash] || input[:io_hash].empty?
    io_hash = { debug_mode: "No", plasmid_stock_ids: [] }.merge io_hash
    if io_hash[:debug_mode].downcase == "yes"
      def debug
        true
      end
    end
    
    if io_hash[:CHO_transfected_strain_ids].length == 0
      show {
        title "No transfections required"
        note "No CHO transfections need to be done. Thanks for your effort!"
      }
      return { io_hash: io_hash }
    end

    io_hash[:plasmid_stock_ids] = io_hash[:CHO_transfected_strain_ids].collect { |cid| choose_stock(find(:sample, id: cid)[0].properties["Plasmid"]) }
    io_hash[:CHO_strain_ids] = io_hash[:CHO_transfected_strain_ids].collect { |cid| find(:sample, id: cid)[0].properties["Parent"].id }
    
    CHO_cells = io_hash[:CHO_strain_ids] = io_hash[:CHO_transfected_strain_ids].collect { |cid| find(:sample, id: cid)[0].properties["Parent"].id }
    CHO_cells_full = [] # an array of CHO aliquots include nils.
    no_CHO_transfected_strain_ids = []
    aliquot_num_hash = Hash.new {|h,k| h[k] = 0 }
    cell_num_hash = Hash.new {|h,k| h[k] = 0 }
    io_hash[:CHO_strain_ids].each_with_index do |cid, idx|
      c = find(:sample, id: cid )[0]
      aliquot_num_hash[c.name] += 1
      if c.in("CHO Aliquot")[ aliquot_num_hash[y.name] - 1 ]
        competent_cell = c.in("CHO Aliquot")[ aliquot_num_hash[c.name] - 1 ]
      else
        cell_num_hash[y.name] += 1
        competent_cell = c.in("CHO Cell")[ cell_num_hash[c.name] - 1 ]
      end

      if competent_cell
        CHO_cells.push competent_cell
        CHO_cells_full.push competent_cell.id
      else
        CHO_cells_full.push "NA"
        no_CHO_transfected_strain_ids.push io_hash[:CHO_strain_ids][idx]
        io_hash[:CHO_strain_ids][idx] = nil
        io_hash[:plasmid_stock_ids][idx] = nil
      end

    end

    io_hash[:CHO_transfected_strain_ids].compact! # remove nil
    io_hash[:plasmid_stock_ids].compact! # remove nil
    plasmid_stocks = io_hash[:plasmid_stock_ids].collect{ |pid| find(:item, id: pid )[0] }
    
    plasmids = plasmid_stocks.collect { |p| p.sample }

    if no_CHO_transfected_strain_ids.length > 0
      show {
        title "Some transformations can not be done"
        note "Transformation for the following yeast strain can not be performed since there are not enough CHO aliquots."
        note no_CHO_transfected_strain_ids
      }
    end

    if CHO_cells.length == 0
      show {
        title "No transfections required"
        note "No transfections need to be done. Thanks for your effort!"
      }
      return { io_hash: io_hash }
    end

    take CHO_cells + plasmid_stocks, interactive: true, method: "boxes"
    
    ensure_stock_concentration plasmid_stocks

    CHO_transformation_mixtures = io_hash[:CHO_strain_ids].collect {|cid| produce new_sample find(:sample, id: cid)[0].name, of: "Strain", as: "Transformation Mixture"}

    # show {
    #   title "Testing page"
    #   note(yeast_competent_cells.collect {|x| x.id})
    #   note(yeast_transformation_mixtures.collect {|x| x.id})
    # }

    # peg = choose_object "50 percent PEG 3350"
    # lioac = choose_object "1.0 M LiOAc"
    # ssDNA = choose_object "Salmon Sperm DNA (boiled)"
    # take [peg] + [lioac] + [ssDNA], interactive: true

    ## Currently here.
    
    tab = [["Old id","New id"]]
    CHO_cells.each_with_index do |y,idx|
      tab.push([y.id,CHO_transformation_mixtures[idx].id])
    end

    show {
      title "Yeast transformation preparation"
      check "Spin down all the Yeast Competent Aliquots on table top centrifuge for 20 seconds"
      check "Add 240 µL of 50% PEG into each competent aliquot tube using the P1000 pipette tips with a filter!"
      note "Press the plunger to the first stop and insert the pipette tip into the PEG aliquot. Depress the plunger and wait at least 30 seconds before removing the pipette tip from the PEG. Because PEG is extremely viscous, it will take time for the entire 240 µL volume to be drawn into the pipette tip. Once the volume within the pipette tip stops increasing (watch for a meniscus within the tip to stop rising!), very slowly withdraw the pipette tip from the PEG. After removing the tip, make sure there are no air bubbles near the end of the tip. If there are any air bubbles, then you withdrew the tip too quickly and need to start over. Try to scrape off any excess PEG along the sides of the tube while withdrawing the pipette tip from the PEG aliquot. Slowly dispense the PEG into the vial of yeast cells. Do not mix."
      check "Add 36 µL of 1M LiOAc to each tube"
      check "Add 5 µL of 10 mg/ml salmon sperm ssDNA to each tube"
      warning "The order of reagents added is super important for suceess of transformation."
    }
    
    plasmid_stocks_volumes = plasmid_stocks.collect { |p| (2000/(p.datum[:concentration])).round(1) }
     
    water_volumes = plasmid_stocks_volumes.collect { |v| 70-v }
    
    plasmid_stock_water_table = [["Yeast Competent Aliquot", "Plasmid Stock", "DI water"]]
    
    CHO_cells.each_with_index do |c, idx|
      plasmid_stock_water_table.push [c.id, { content: "#{plasmid_stocks_volumes[idx]} µL of #{plasmid_stocks[idx]}", check: true }, { content: "#{water_volumes[idx]} µL", check: true }]
    end
    
    
    show {
      title "Load plasmid stock and water"
      table plasmid_stock_water_table  
    }

    show {
      title "Re-label all the competent cell tubes"
      table [["Old id","New id"]].concat(CHO_cells.collect {|c| c.id }.zip CHO_transformation_mixtures.collect { |c| { content: c.id, check: true } })
    }
    
    show {
      title "Vortex strongly"
      check "Vortex vigorously until the cells and the above components have been completely mixed."
      note "This usually takes about 1 minute. After vortexing, the phase separation should disappear and the viscosity from the PEG should be significantly reduced."
    }
    
    show {
      title "Incubate for 30 minutes"
      check "Incubate for 30 minutes at 30°C with shaking (200 rpm)."
      note "Tape your tubes of yeast to the side of an Erlenmeyer flask and put your flask in the orbital shaker in the 30°C warm room in 68-074 across the hall."
      timer initial: { hours: 0, minutes: 30, seconds: 0}
    }
    
    show {
      title "Heat shock"
      check "Place all aliquots in a 42 C water bath for 20 minutes. Water baths are located in 68-077 and 68-074 across the hall."
    }

    show {
      title "Retrive tubes and spin down"
      timer initial: { hours: 0, minutes: 20, seconds: 0}
      check "Retrive all #{CHO_transformation_mixtures.length} tubes from 42 C heat block."
      check "Spin the tube down for 20 seconds at 6000 rpm."
      check "Remove all the supernatant carefully with a 1000 µL pipettor (~400 µL total) while leaving the cell pellet intact."
    }

    CHO_markers = plasmids.collect {|p| p.properties["Yeast Marker"].downcase[0,3]}
    CHO_transformation_mixtures_markers = Hash.new {|h,k| h[k] = [] }
    CHO_transformation_mixtures.each_with_index do |y,idx|
      CHO_markers.uniq.each do |mk|
        CHO_transformation_mixtures_markers[mk].push y if yeast_markers[idx] == mk
      end
    end

    mixtures_to_incubate = []
    mixtures_to_plate = []
    CHO_plates = []

    grab_plate_tab = [["Plate type","Quantity","Id to label"]]
    plating_info_tab = [["1.5 mL tube id","Plate id"]]

    CHO_transformation_mixtures_markers.each do |key, mixtures|
      if ["nat","kan","hyg","ble"].include? key
        mixtures_to_incubate.concat mixtures
      else
        CHO_plates_sub = mixtures.collect {|v| produce new_sample v.sample.name, of: "Yeast Strain", as: "Yeast Plate"}
        CHO_plates.concat CHO_plates_sub
        mixtures_to_plate.concat mixtures

        grab_plate_tab.push(["-#{key.upcase}", CHO_plates_sub.length, CHO_plates_sub.collect { |y| y.id }.join(", ")])
        mixtures.each_with_index do |y,idx|
          plating_info_tab.push([y.id, CHO_plates_sub[idx].id])
        end
      end
    end

    if mixtures_to_incubate.length > 0
      show {
        title "Resuspend in YPAD and incubate"
        check "Grab #{"tube".pluralize(mixtures_to_incubate.length)} with id #{(mixtures_to_incubate.collect {|x| x.id}).join(", ")}"
        check "Add 1 mL of YPAD to the each tube and vortex for 20 seconds"
        check "Grab #{mixtures_to_incubate.length} 14 mL #{"tube".pluralize(mixtures_to_incubate.length)}, label with #{(mixtures_to_incubate.collect {|x| x.id}).join(", ")}"
        check "Transfer all contents from each 1.5 mL tube to corresponding 14 mL tube that has the same label number"
        check "Place all #{mixtures_to_incubate.length} 14 mL #{"tube".pluralize(mixtures_to_incubate.length)} into 30 C shaker incubator"
        check "Discard all #{mixtures_to_incubate.length} empty 1.5 mL #{"tube".pluralize(mixtures_to_incubate.length)} "
      }
      mixtures_to_incubate.each do |y|
        y.location = "30 C shaker incubator"
        y.save
      end
      release mixtures_to_incubate
    end

    if mixtures_to_plate.length > 0
      show {
        title "Grab plate"
        note "Grab the following plates and label with ids."
        table grab_plate_tab
      }
      show {
        title "Resuspend in water and plate"
        check "Add 200 µL of MG water to the following mixtures shown in the table."
        check "Flip the plate and add 4-5 glass beads to it, add 200 µL of mixtures on each plate."
        table plating_info_tab
      }

      show {
        title "Shake and incubate"
        check "Shake the plates in all directions to evenly spread the culture over its surface till dry."
        check "Discard the beads in a used beads container."
        check "Throw away the following 1.5 mL tubes."
        note mixtures_to_plate.collect { |x| "#{x}"}
        check "Incubate all the plates with agar side up shown in the next page."
      }

      delete mixtures_to_plate
      move CHO_plates, "30 C incubator"
      release CHO_plates, interactive: true

    end

    # delete yeast_competent_cells

    # release [peg] + [lioac] + [ssDNA], interactive: true

    if io_hash[:task_ids]
      io_hash[:task_ids].each do |tid|
        task = find(:task, id: tid)[0]
        set_task_status(task,"transformed")
      end
    end
    io_hash[:plate_ids]= CHO_plates.collect {|x| x.id} if yeast_plates.length > 0

    io_hash[:CHO_transformation_mixture_ids] = mixtures_to_incubate.collect { |y| y.id }
    
    return { io_hash: io_hash }

  end

end
