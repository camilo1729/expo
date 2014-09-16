Expo: Experiment Engine for Distributed Platforms
=================================================

**Homepage**: [http://expo.gforge.inria.fr/](http://expo.gforge.inria.fr)

**Authors**:   Cristian Ruiz, Brice Videau, Olivier Richard.



## Synopsis


Expo is an experiment engine for distributed platforms. It aims at simplifying the experimental process on such platforms.


## Installation

Procedure to install in Grid5000

``` sh
export https_proxy="http://proxy:3128"
git clone https://github.com/camilo1729/expo.git
export GEM_HOME=~/.gem/
cd expo && bundle install
```

## Running a simple experiment


Before running you have to change some experiment parameters such as "username"
``` sh
export GEM_HOME=~/.gem/
cd /PATH_TO_EXPO_REPOSITORY/expo_new
bn/expo examples/simple_experiment.rb
```

## DSL commands

``` ruby

run("command to run", :target => "node")
check("command")
put("file","path",:method => "scp")
get("file","path",:method => "scp")
```


## Contact

cristian.ruiz@imag.fr or report a bug in {https://lists.gforge.inria.fr/mailman/listinfo/expo-users Expo Mailing List}

<a name="publications"></a>


## Related Publications

Brice Videau, Corinne Touati, and Olivier Richard.
Toward an experiment engine for lightweight grids. In MetroGrid workshop : Metrology for Grid Networks. ACM publishing, Lyon, France, October 2007.
{file:docs/bib/Metro07.html bibtex}

Brice Videau and Olivier Richard. Expo : un moteur de conduite d'expériences pour plates-formes dédiées. In Conférence Française en Systèmes d'Exploitation (CFSE), Fribourg, Switzerland, February 2008.
{file:docs/bib/CFSE6.html bibtex}

Cristian Ruiz, Olivier Richard, Videau Brice and Oleg Iegorov.
Managing Large Scale Experiments in Distributed Testbeds. Parallel and Distributed Computing and Networks (PDCN 2013) Conference in Innsbruck, Austria.
{file:docs/bib/PDCN2013.html bibtex}

## Changelog

- **Nov.19.12**: Released 0.4a experimental version for testing. The goal here is to get people testing Expo and know if it really makes easy the experimentation process.

- **Mar.8.10**: Added Ruby commands.
