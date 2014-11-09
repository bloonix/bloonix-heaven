Summary: Bloonix Heaven
Name: bloonix-heaven
Version: 0.4
Release: 1%{dist}
License: Commercial
Group: Utilities/System
Distribution: RHEL and CentOS

Packager: Jonny Schulz <js@bloonix.de>
Vendor: Bloonix

BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Source0: http://download.bloonix.de/sources/%{name}-%{version}.tar.gz
Requires: bloonix-core
Requires: bloonix-fcgi
Requires: perl-JSON-XS
Requires: perl(JSON)
Requires: perl(Log::Handler)
Requires: perl(Getopt::Long)
AutoReqProv: no

%description
bloonix-heaven is a mvc web framework.

%prep
%setup -q -n %{name}-%{version}

%build
%{__perl} Build.PL installdirs=vendor
%{__perl} Build

%install
%{__perl} Build install destdir=%{buildroot} create_packlist=0
find %{buildroot} -name .packlist -exec %{__rm} {} \;
find %{buildroot} -type f -name .packlist -exec rm -f {} ';'
find %{buildroot} -type f -name '*.bs' -a -size 0 -exec rm -f {} ';'
find %{buildroot} -type d -depth -exec rmdir {} 2>/dev/null ';'
%{_fixperms} %{buildroot}/*

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc ChangeLog INSTALL LICENSE
%{perl_vendorlib}/*
%{_mandir}/man3/*

%changelog
* Mon Nov 03 2014 Jonny Schulz <js@bloonix.de> - 0.4-1
- Updated the license information.
* Fri Oct 24 2014 Jonny Schulz <js@bloonix.de> - 0.3-1
- Disable die_on_errors by default so that the logger
  does not die on errors.
* Thu Oct 16 2014 Jonny Schulz <js@bloonix.de> - 0.2-1
- Improved the error handling.
- Added parameter "minimal" to validate().
- Deleted ModelLoader.pm.
* Mon Aug 25 2014 Jonny Schulz <js@bloonix.de> - 0.1-1
- Initial release.
