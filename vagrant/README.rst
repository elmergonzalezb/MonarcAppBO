Development environment for MONARC
==================================

Vagrant is convenient to use in order to setup your development environment.

This VM uses `synced folders <https://www.vagrantup.com/docs/synced-folders/>`_
feature of Vagrant in order to let you work on the MONARC source code on your
host machine while the softwares (Apache, PHP, MariaDB, etc.) and libraries
will be installed on the guest Vagrant machine.


Installation of VirtualBox and Vagrant
--------------------------------------

.. code-block:: bash

    $ sudo apt install virtualbox vagrant


Deployment of the back office
------------------------------

MONARC will be automatically deployed in an Ubuntu Artful Server.

.. code-block:: bash

    $ git clone https://github.com/monarc-project/MonarcAppBO
    $ cd MonarcAppBO/vagrant
    $ export GITHUB_AUTH_TOKEN=<your-github-auth-token>
    $ vagrant up

Once the VM will be configured by Vagrant, go to the address
http://127.0.0.1:5000.

The username is *admin@admin.test* and the password is *admin*.

You can now edit the source code with your favorite editor and test it in your
browser. The only thing is to not forget to restart Apache in the VM after a
modification.
