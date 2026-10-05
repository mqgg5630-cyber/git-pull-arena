# AMP Vina docking task - round 255
time=2026-10-05 15:03:05 +08:00
host=LAPTOP-R77M5D6M

## Task scope
Peptides: FVNKLNRIIPVKGFSMR; LISNTKKFGTAIASHR; ISLAIPLASKISGFTLALVKNAST
Targets: E. coli FtsZ + GyrB, S. aureus FtsZ + Sortase A
Replicates: 3 Vina repeats per peptide-target pair; report mean of best scores.

desktop_probe=DESKTOP-IEUDGS5
pymol_mcp_path=E:\0mcp-agv\.agents\skills\pymol-mcp exists=True
execution_machine=laptop_or_current_watcher_machine

python=E:\spider\python.exe
python_version=3.11.9 | packaged by conda-forge | (main, Apr 19 2024, 18:27:10) [MSC v.1938 64 bit (AMD64)]
## Dependency setup
pip_core| Python311\Scripts' which is not on PATH.
pip_core| ???? ?:1 ??: 2
pip_core| +  & $using:py -m pip install --user --upgrade --quiet numpy matplotlib ...
pip_core| +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pip_core|     + CategoryInfo          : NotSpecified: (  WARNING: The ...is not on PATH.:String) [], RemoteException
pip_core|     + FullyQualifiedErrorId : NativeCommandError
pip_core|   Consider adding this directory to PATH or, if you prefer to suppress this warning, use --no-warn-script-location.
pip_core| ERROR: pip's dependency resolver does not currently take into account all the packages that are installed. This behavio
pip_core| ur is the source of the following dependency conflicts.
pip_core| pymol 3.1.0 requires numpy<2,>=1.26.4, but you have numpy 2.4.6 which is incompatible.
pip_core| [notice] A new release of pip is available: 25.2 -> 26.2.1
pip_core| [notice] To update, run: E:\spider\python.exe -m pip install --upgrade pip
pip_rdkit| python.exe : 
pip_rdkit| ???? ?:1 ??: 2
pip_rdkit| +  & $using:py -m pip install --user --upgrade --quiet rdkit 2>&1 | Out ...
pip_rdkit| +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pip_rdkit|     + CategoryInfo          : NotSpecified: (:String) [], RemoteException
pip_rdkit|     + FullyQualifiedErrorId : NativeCommandError
pip_rdkit| [notice] A new release of pip is available: 25.2 -> 26.2.1
pip_rdkit| [notice] To update, run: E:\spider\python.exe -m pip install --upgrade pip
pip_vina|       mm.run()
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\command\egg_info.py", line 543, in run
pip_vina|       self.add_defaults()
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\command\egg_info.py", line 581, in add_defaults
pip_vina|       sdist.add_defaults(self)
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\command\sdist.py", line 109, in add_defaults
pip_vina|       super().add_defaults()
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\_distutils\command\sdist.py", line 239, in add_defaults
pip_vina|       self._add_defaults_ext()
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\_distutils\command\sdist.py", line 323, in _add_defaults_ext
pip_vina|       build_ext = self.get_finalized_command('build_ext')
pip_vina|                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\_distutils\cmd.py", line 316, in get_finalized_command
pip_vina|       cmd_obj.ensure_finalized()
pip_vina|     File "E:\spider\Lib\site-packages\setuptools\_distutils\cmd.py", line 124, in ensure_finalized
pip_vina|       self.finalize_options()
pip_vina|     File "C:\Users\??\AppData\Local\Temp\pip-install-eids7d32\[REDACTED]\setup.py", line 217
pip_vina| , in finalize_options
pip_vina|       raise ValueError(error_msg)
pip_vina|   ValueError: Boost library location was not found!
pip_vina|   Directories searched: conda env, /usr/local/include and /usr/include.
pip_vina|   [end of output]
pip_vina|   note: This error originates from a subprocess, and is likely not a problem with pip.
pip_vina| [notice] A new release of pip is available: 25.2 -> 26.2.1
pip_vina| [notice] To update, run: E:\spider\python.exe -m pip install --upgrade pip
pip_vina| error: metadata-generation-failed
pip_vina| Encountered error while generating package metadata.
pip_vina| See above for output.
pip_vina| note: This is an issue with the package mentioned above, not pip.
pip_vina| hint: See above for details.
import| python.exe : Traceback (most recent call last):
import| ???? ?:1 ??: 2
import| +  & $using:py -c "import rdkit, vina, matplotlib, numpy; print('IMPORT ...
import| +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
import|     + CategoryInfo          : NotSpecified: (Traceback (most recent call last)::String) [], RemoteException
import|     + FullyQualifiedErrorId : NativeCommandError
import|   File "<string>", line 1, in <module>
import| ModuleNotFoundError: No module named 'vina'
DEPENDENCIES_OK=False
AMP_DOCKING_DONE=False
