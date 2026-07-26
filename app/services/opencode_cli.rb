require "open3"

class OpencodeCli
  def self.exec(*args, env: {})
    Open3.capture3(env, "opencode", *args, chdir: Rails.root.to_s)
  end
end
