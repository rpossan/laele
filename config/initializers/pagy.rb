# Pagy initializer file (9.4.0)
# Customize only what you really need but notice that the core Pagy works also without any of the following lines.
# Should you just cherry pick part of this file, please maintain the require-order and the constants-order.

# Extras
# See https://ddnexus.github.io/pagy/docs/extras
#
# Backend Extras
# require 'pagy/extras/arel'
# require 'pagy/extras/array'
# require 'pagy/extras/calendar'
# require 'pagy/extras/countless'
# require 'pagy/extras/elasticsearch_rails'
# require 'pagy/extras/headers'
# require 'pagy/extras/jsonapi'
# require 'pagy/extras/keyset'
# require 'pagy/extras/limit'
# require 'pagy/extras/meilisearch'
# require 'pagy/extras/searchkick'

# Frontend Extras
# require 'pagy/extras/bootstrap'
# require 'pagy/extras/bulma'
# require 'pagy/extras/foundation'
# require 'pagy/extras/materialize'
# require 'pagy/extras/navs'
# require 'pagy/extras/semantic'
# require 'pagy/extras/uikit'

# Feature Extras
# require 'pagy/extras/gearbox'
# require 'pagy/extras/overflow'
# require 'pagy/extras/size'
# require 'pagy/extras/trim'

# Pagy Variables
# See https://ddnexus.github.io/pagy/docs/api/pagy#variables
# All the Pagy::DEFAULT are set for all the Pagy instances but can be overridden per instance by just passing them to
# Pagy.new|Pagy::Countless.new|Pagy::Calendar::*.new or any of the #pagy* controller methods

# Instance variables
# See https://ddnexus.github.io/pagy/docs/api/pagy#instance-variables
Pagy::DEFAULT[:page]   = 1                                  # default
Pagy::DEFAULT[:items]  = 10                                 # changed from 25 to 10
Pagy::DEFAULT[:outset] = 0                                  # default

# Other Variables
# See https://ddnexus.github.io/pagy/docs/api/pagy#other-variables
Pagy::DEFAULT[:size]       = 7                              # default
Pagy::DEFAULT[:page_param] = :page                          # default
# The :params can be also set as a lambda e.g ->(params){ params.exclude('useless').merge!('custom' => 'useful') }
Pagy::DEFAULT[:params]     = {}                             # default
Pagy::DEFAULT[:fragment]   = ''                             # removed fragment
# Pagy::DEFAULT[:link_extra] = 'data-remote="true"'        # removed global link_extra
Pagy::DEFAULT[:i18n_key]   = 'pagy.item_name'              # default
Pagy::DEFAULT[:cycle]      = true                           # example

# Extras
# See https://ddnexus.github.io/pagy/docs/extras

# Metadata extra: Provides the pagination metadata to Javascript frameworks like Vue.js, react.js, etc.
require 'pagy/extras/metadata'

# Overflow extra: Allow for easy handling of overflowing pages
require 'pagy/extras/overflow'
Pagy::DEFAULT[:overflow] = :last_page                       # default  (other options: :empty_page and :exception)

# Support for non-english locales
# See https://ddnexus.github.io/pagy/docs/api/frontend#i18n
# For performance reasons, please set it explicitly only if you are going to use it
# I18n.available_locales = [:en, :es, :de, :fr, ...]

# I18n inflections (for non-english locales)
# See https://ddnexus.github.io/pagy/docs/api/frontend#i18n
# For performance reasons, please set it explicitly only if you are going to use it
# I18n::Backend::Simple.include I18n::Backend::Pluralization
