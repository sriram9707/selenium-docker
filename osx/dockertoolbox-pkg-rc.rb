# Forked from:
#  https://github.com/caskroom/homebrew-cask/blob/master/Casks/dockertoolbox.rb
# Docs:
#  https://github.com/astorije/homebrew-cask/blob/master/CONTRIBUTING.md#cask-stanzas
cask 'dockertoolbox-rc' do
  version '1.12.0-rc4'

  # shasum -a 256 DockerToolbox-1.12.0-rc4.pkg
  sha256 '95ac6d6688c08443f9e42926f50c058083fc96fee8cd9ec124644572956d32a0'
  # github.com/docker/toolbox was verified as official when first introduced to the cask
  url "https://github.com/docker/toolbox/releases/download/v#{version}/DockerToolbox-#{version}.pkg"

  # appcast URL for an appcast which provides information on future updates
  #  https://github.com/caskroom/homebrew-cask/blob/master/doc/cask_language_reference/stanzas/appcast.md
  #  curl --compressed -L "https://github.com/docker/toolbox/releases.atom" | \
  #    sed 's|<pubDate>[^<]*</pubDate>||g' | shasum -a 256
  appcast 'https://github.com/docker/toolbox/releases.atom',
          checkpoint: '1099f331135a6e1178c057cdd6938dca3102d37cb245f574b33833f2d78e67a7'

  name 'Docker Toolbox'
  homepage 'https://www.docker.com/toolbox'
  license :apache

  pkg "DockerToolbox-#{version}.pkg"

  postflight do
    set_ownership '~/.docker'
  end

  uninstall pkgutil: [
                       'io.boot2dockeriso.pkg.boot2dockeriso',
                       'io.docker.pkg.docker',
                       'io.docker.pkg.dockercompose',
                       'io.docker.pkg.dockermachine',
                       'io.docker.pkg.dockerquickstartterminalapp',
                       'io.docker.pkg.kitematicapp',
                     ]
end
