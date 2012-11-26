function [lprim_cell, Npml] = generate_lprim3d(domain, Lpml, shape_array, src_array, withuniform)

% Check "domain".
chkarg(istypesizeof(domain, 'Domain'), '"domain" should be instance of Domain.');

% Check "Lpml".
chkarg(istypeof(Lpml, 'real'), 'element of "Lpml" should be real.');
chkarg(isexpandable2mat(Lpml, Axis.count, Sign.count), ...
	'"Lpml" should be scalar, length-%d vector, or %d-by-%d matrix.', Axis.count, Axis.count, Sign.count);
Lpml = expand2mat(Lpml, Axis.count, Sign.count);

% Check "shape_array".
chkarg(istypesizeof(shape_array, 'Shape', [1 0]), ...
	'"shape_array" should be row vector of instances of Shape.');

% Check "src_array".
if nargin < 4  % no src_array
	src_array = [];
end
chkarg(istypesizeof(src_array, 'Source', [1 0]), '"src_array" should be row vector of Source objects.');

if nargin < 5  % no withuniform
	withuniform = false;
end
chkarg(istypesizeof(withuniform, 'logical'), '"withuniform" should be logical.');

lprim_cell = cell(1, Axis.count);
Npml = NaN(Axis.count, Sign.count);
if withuniform
	for w = Axis.elems
		dl_intended = domain.dl_max(w);
		Nw = round(domain.L(w) / dl_intended);
		lprim = linspace(domain.bound(w,Sign.n), domain.bound(w,Sign.p), Nw+1);
		assert(length(lprim) >= 2);
		dl_generated = lprim(2) - lprim(1);
		if dl_generated ~= dl_intended
			warning('FDS:gridGen', 'grid vertex separation %e in generated uniform grid differs from intended separation %e by %e percent.', ...
				dl_generated, dl_intended, (dl_generated-dl_intended)/dl_intended * 100);
		end
		Npml(w,Sign.n) = length(find(lprim < lprim(1) + Lpml(w,Sign.n)));
		Npml(w,Sign.p) = length(find(lprim > lprim(end) - Lpml(w,Sign.p)));
		lprim_cell{w} = lprim;
	end
else  % withuniform == false: use dynamic grid generation algorithm
	intervals = cell(1, Axis.count);
	for j = 1:length(shape_array)
		shape = shape_array(j);
		for w = Axis.elems
			inters_w = intervals{w};  % initially empty
			inter_curr = shape.interval(w);
			is_new = true;
			i = 1;
			while is_new && i <= length(inters_w)
				is_new = is_new && ~isequal(inters_w(i), inter_curr);  % isequal() compares contents of two objects
				i = i + 1;
			end

			% Keep only a new interval; many intervals can be the same, e.g., in a
			% photonic crystal.
			if is_new
				intervals{w} = [inters_w, inter_curr];
			end
		end
	end

	lprim0 = cell(1, Axis.count);
	ldual0 = cell(1, Axis.count);
	for j = 1:length(src_array)
		src = src_array(j);
		for w = Axis.elems
			lprim0{w} = [lprim0{w}, src.l{w, GK.prim}];
			ldual0{w} = [ldual0{w}, src.l{w, GK.dual}];
		end
	end

	for w = Axis.elems
		try
			lprim_part = generate_lprim1d_part(domain.interval(w), Lpml(w,:), intervals{w}, lprim0{w}, ldual0{w});
			lprim = complete_lprim1d(lprim_part);
		catch err1
			try
				lprim_part = generate_lprim1d_part(domain.interval(w), Lpml(w,:), intervals{w}, lprim0{w}, []);
				lprim = complete_lprim1d(lprim_part);
				ldual = mean([lprim(1:end-1); lprim(2:end)]);  % take average in column
			catch err2
				exception = MException('FDS:gridGen', '%s-axis grid generation failed.', char(w));
				throw(addCause(exception, err2));
			end
			
			if ~isempty(setdiff(ldual0{w}, ldual))
				exception = MException('FDS:gridGen', '%s-axis grid generation failed.', char(w));
				throw(addCause(exception, err1));
			end
		end
		Npml(w,Sign.n) = length(find(lprim < lprim(1) + Lpml(w,Sign.n)));
		Npml(w,Sign.p) = length(find(lprim > lprim(end) - Lpml(w,Sign.p)));
		lprim_cell{w} = lprim;
	end
end