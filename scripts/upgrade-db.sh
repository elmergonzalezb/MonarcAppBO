#!/bin/bash

php ./vendor/robmorgan/phinx/bin/phinx migrate -c ./module/Monarc/Core/migrations/phinx.php

php ./vendor/robmorgan/phinx/bin/phinx migrate -c ./module/Monarc/BackOffice/migrations/phinx.php
