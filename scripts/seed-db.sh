#!/bin/bash

php ./vendor/robmorgan/phinx/bin/phinx seed:run -c ./module/Monarc/Core/migrations/phinx.php

php ./vendor/robmorgan/phinx/bin/phinx seed:run -c ./module/Monarc/BackOffice/migrations/phinx.php

