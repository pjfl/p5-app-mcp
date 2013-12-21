# Name

App::MCP - Master Control Program - Dependency and time based job scheduler

# Version

This documents version v0.3.$Rev: 9 $

# Synopsis

    use App::MCP::Daemon;

    exit App::MCP::Daemon->new_with_options
       ( appclass => 'App::MCP', noask => 1 )->run;

# Description

# Configuration and Environment

# Subroutines/Methods

# Diagnostics

# Dependencies

- [CatalystX::Usul::TraitFor::ConnectInfo](https://metacpan.org/pod/CatalystX::Usul::TraitFor::ConnectInfo)
- [Class::Usul](https://metacpan.org/pod/Class::Usul)
- [IPC::PerlSSH](https://metacpan.org/pod/IPC::PerlSSH)
- [TryCatch](https://metacpan.org/pod/TryCatch)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
