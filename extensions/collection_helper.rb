class CollectionHelper
  def self.match_and_group(model, match_op, group_op)
    model.collection.aggregate([{"$match" => match_op}, {"$group" => group_op}])
  end
  
  def self.merge_timelines(timeline_set)
    earliest = timeline_set.values.collect{|x| x.sort.first}.collect(&:first).sort.first rescue nil
    latest = timeline_set.values.collect{|x| x.sort.last}.collect(&:first).sort.last rescue nil
    return [] if earliest.nil? && latest.nil?
    cursor = earliest
    width = 24*60*60
    dataset = []
    keys = timeline_set.keys
    dataset << ["x", keys].flatten
    while cursor <= latest
      row = [cursor.strftime("%Y-%m-%d")]
      keys.each do |k|
        timeline_set[k][cursor].nil? ? row << 0 : row << timeline_set[k][cursor]
      end
      dataset << row
      cursor += width
    end
    dataset.transpose
  end
end