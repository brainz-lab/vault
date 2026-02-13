# frozen_string_literal: true

# Creates a symlink so Tailwind CSS can resolve brainzlab-ui stylesheets from the gem.
# The symlink points app/assets/tailwind/brainzlab_ui -> gem's stylesheet directory.
Rails.application.config.after_initialize do
  gem_spec = Gem.loaded_specs["brainzlab-ui"]
  next unless gem_spec

  source = Pathname.new(gem_spec.full_gem_path).join("app/assets/stylesheets/brainzlab_ui")
  target = Rails.root.join("app/assets/tailwind/brainzlab_ui")

  next unless source.exist?

  # Remove stale symlink (e.g., after gem update)
  if target.symlink? && !target.exist?
    FileUtils.rm(target)
  end

  unless target.exist?
    FileUtils.ln_s(source, target)
  end
end
