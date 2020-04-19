include envfile.ini
export $(shell sed 's/=.*//' envfile.ini)

dir=${CURDIR}
frontenddir=$(dir)/public
storedir=$(dir)/store

install:
	# Clean up from failed install
	@if [ -f "$(dir)/downloads/frontend.zip" ]; then rm -f "$(dir)/downloads/frontend.zip"; fi
	@if [ -d "$(dir)/tmp" ]; then rm -rf "$(dir)/tmp"; fi

	# Create folders
	@if [ ! -d "$(dir)/downloads" ]; then mkdir "$(dir)/downloads"; fi
	@if [ ! -d "$(dir)/tmp" ]; then mkdir "$(dir)/tmp"; fi

	# Download the compiled dist from nxfifteen
	@if [ -f "$(dir)/downloads/frontend.zip" ]; then rm -f "$(dir)/downloads/frontend.zip"; fi
	@curl -s -L --output "$(dir)/downloads/frontend.zip" "https://nxfifteen.me.uk/downloads/public/nx-core/frontend/angular-$(frontendbranch).zip"

	# Extracting the zip folder
	@cd "$(dir)/tmp" && unzip -qq "$(dir)/downloads/frontend.zip"

	# If its a reinstall store the config safely
	@if [ -f "$(frontenddir)/assets/app-config.json" ]; then mv "$(frontenddir)/assets/app-config.json" "$(dir)/tmp/"; fi
	@if [ -d "$(frontenddir)/assets/custom" ]; then mv "$(frontenddir)/assets/custom" "$(dir)/tmp/"; fi
	@if [ -f "$(storedir)/.env.local" ]; then mv "$(storedir)/.env.local" "$(dir)/tmp/.env.local"; fi

	# Removing any old instances
	@cd "$(frontenddir)" && rm -rf ./*

	# Moved the extracted files into their install folder
	@cd "$(dir)/tmp/dist/out" && mv ./* "$(frontenddir)/"

	# Installing Store from Git
	@if [ -d "$(storedir)" ]; then rm -rf "$(storedir)"; fi
	@git clone https://gitlab.com/nx-core/store.git "$(storedir)"
	@cd "$(storedir)" && git checkout $(storebranch)

	# If its a reinstall put the config back
	@if [ -f "$(dir)/tmp/app-config.json" ]; then mv "$(dir)/tmp/app-config.json" "$(frontenddir)/assets/app-config.json" ; fi
	@if [ -d "$(dir)/tmp/custom" ]; then mv "$(dir)/tmp/custom" "$(frontenddir)/assets/"; fi
	@if [ -f "$(dir)/tmp/.env.local" ]; then mv "$(dir)/tmp/.env.local" "$(storedir)/.env.local"; fi

	# Clean up after the install
	@if [ -f "$(dir)/downloads/frontend.zip" ]; then rm -f "$(dir)/downloads/frontend.zip"; fi
	@if [ -d "$(dir)/tmp" ]; then rm -rf "$(dir)/tmp"; fi

	@make configure
	@make migrate

configure:
	# Creating local configuration files
	@if [ ! -f "$(frontenddir)/assets/app-config.json" ]; then cp "$(frontenddir)/assets/app-config.json.dist" "$(frontenddir)/assets/app-config.json"; fi
	@if [ ! -f "$(storedir)/.env.local" ]; then cp "$(storedir)/.env.local.dist" "$(storedir)/.env.local"; sed -i "s|TIMEZONE=CHANGEME|TIMEZONE=${TZ}|g" "$(storedir)/.env.local"; fi

	@echo
	@echo "You now need to configure the local config file. For full instructions check out the documentation at:"
	@echo "https://nxfifteen.me.uk/projects/nxcore/"

	@make settings

	@make build

	@cd "$(storedir)" && composer dump-env production

settings:
	@echo
	@echo -n "Are you ready to continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo

	@echo -n "First we'll configure the frontend [Y/n] " && read ans && [ $${ans:-Y} = Y ]
	@${EDITOR} "$(frontenddir)/assets/app-config.json"

	@echo -n "Next we'll configure the backend [Y/n] " && read ans && [ $${ans:-Y} = Y ]
	@${EDITOR} "$(storedir)/.env.local"

build:
	# Install composer deps
	@cd "$(storedir)" && composer install

clear-cache:
	@cd "$(storedir)" && php ./bin/console cache:clear

info:
	@cd "$(storedir)" && php ./bin/console --version

doctrine:
	@cd "$(storedir)" && php ./bin/console doctrine:migrations:$(RUN_ARGS)

migrate:
	@cd "$(storedir)" && php ./bin/console doctrine:migrations:migrate --no-interaction --all-or-nothing
