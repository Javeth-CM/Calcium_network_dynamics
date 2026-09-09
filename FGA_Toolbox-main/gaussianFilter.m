function filteredData = gaussianFilter(rawData, sampfreq, cornerfreq)
fc = cornerfreq/sampfreq;
sigma = 0.132505/fc;
nc = round(4*sigma);
coeffs = -nc:nc;
coeffs = exp((-coeffs.^2)/(2*sigma^2))/(sqrt(2*pi)*sigma);
filteredData = conv(rawData,coeffs);
filteredData = filteredData(nc+1:end-nc);
end

