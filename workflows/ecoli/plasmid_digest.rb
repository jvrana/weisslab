needs "aqualib/lib/standard"
needs "aqualib/lib/cloning"

class Protocol

  include Standard
  include Cloning


  def arguments
    {
      io_hash: {},
      plasmid_stock_ids: [9189,11546,11547,34376,6222,9111],
      debug_mode: "Yes",
    }
  end

  def main
    io_hash = input[:io_hash]
    io_hash = input if !input[:io_hash] || input[:io_hash].empty?
    io_hash = { stripwell_ids: [], plasmid_stock_ids: [], item_choice_mode: "No" }.merge io_hash

    if io_hash[:debug_mode].downcase == "yes"
      def debug
        true
      end
    end

    if io_hash[:plasmid_stock_ids].length == 0
      show {
        title "No plasmid digestion required"
        note "No plasmid digestion required. Thanks for you effort!"
      }
      return { io_hash: io_hash }
    end

    plasmid_stocks = io_hash[:plasmid_stock_ids].collect{ |pid| find(:item, id: pid )[0] }

    plasmids = plasmid_stocks.collect { |p| p.sample }

    take plasmid_stocks, interactive: true, method: "boxes"

    cut_smart = choose_sample "Cut Smart", take: true

    stripwells = produce spread plasmids, "Stripwell", 1, 12

    show {
      title "Grab an ice block"
      warning "In the following step you will take restriction enzyme out of the freezer. Make sure the enzyme is kept on ice for the duration of the protocol."
    }

    pmeI = choose_sample "PmeI", take: true

    num = (plasmid_stocks.select { |p| p.object_type.name == "Plasmid Stock" }).length

    water_volume = 42 * num + 21
    buffer_volume = 5 * num + 2.5
    enzyme_volume = 1 * num + 0.5

    show {
      title "Make master mix"
      check "Label a new eppendorf tube MM."
      check "Add #{water_volume.round(1)} µL of water to the tube."
      check "Add #{buffer_volume.round(1)} µL of the cutsmart buffer to the tube."
      check "Add #{enzyme_volume.round(1)} µL of the PmeI to the tube."
      check "Vortex for 5-10 seconds."
      warning "Keep the master mix in an ice block while doing the next steps".upcase
    }

    release [pmeI] + [cut_smart], interactive: true, method: "boxes"

    show {
      title "Prepare Stripwell Tubes"
      stripwells.each do |sw|
        check "Label a new stripwell with the id #{sw}. Use enough number of wells to write down the id number."
        check "Pipette 48 µL from tube MM into wells" + sw.non_empty_string + "."
      end
    }

    load_samples( ["Plasmid, 2 µL"], [plasmid_stocks], stripwells ) {
      note "Add 2 µL of each plasmid into the stripwell indicated."
      warning "Use a fresh pipette tip for each transfer."
    }

    incubate = show {
      title "Incubate"
      check "Put the cap on each stripwell. Press each one very hard to make sure it is sealed."
      separator
      check "Place the stripwells into a small green tube holder and then place in 37 C incubator."
      image "put_green_tube_holder_to_incubator"
    }

    stripwells.each do |sw|
      sw.move "37 C incubator"
    end

    release stripwells
    release plasmid_stocks, interactive: true, method: "boxes"

    if io_hash[:task_ids]
      io_hash[:task_ids].each do |tid|
        task = find(:task, id: tid)[0]
        set_task_status(task,"plasmid digested")
      end
    end

    io_hash[:stripwell_ids] = stripwells.collect { |s| s.id }
    return { io_hash: io_hash }

  end

end