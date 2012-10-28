clear all; close all; clear classes; clc;

%% Set flags.
isnew = true;
inspect_only = true;

%% Solve the system.
if isnew
	gray = [0.5 0.5 0.5];  % [r g b]
	solveropts.method = 'gpu';
	[E, H, obj_array, err] = maxwell_run(1e-9, 1550, ...
		{['Palik', filesep, 'SiO2'], 'none'}, [0, 700; 0, 600; -200, 1700], 20, [BC.e, BC.m, BC.p], [0 200; 0 200; 200 200], ...
		{['Palik', filesep, 'SiO2'], 'none'}, Box([0, 50; 0, 50; -200, 1700], [2, 2, 20]), ...
		{['Hagemann', filesep, 'Ag'], gray}, Box([25, 700; 0, 25; -200, 1700], 20), ...
		DistributedSrc(Axis.z, 200, 2.0), 1e-5, inspect_only);

	save(mfilename, 'E', 'H', 'obj_array');
else
	load(mfilename);
end

%% Visualize the solution.
if ~inspect_only
	figure;
	opts.withabs = true;
	opts.withgrid = true;
	visall(E{Axis.x}, obj_array, opts);
end
