module StudioApi
  class Build
    def to_s
      "version #{self.version}, #{self.image_type} format"
    end
  end
end
