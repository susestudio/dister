module StudioApi
  class Build
    def to_s
      "version #{self.version}, #{self.image_type} format (#{self.created_at})"
    end
  end
end
