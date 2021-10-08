%% Adjacency-based iteration forecasting model
%% Step 1: Input basic parameters
clear all;
city_n = 285;% city number
SDG_n = 17;% SDG number
threshold = 30;% Range [0,100]; Business as usual=0; slight policy=10; moderate policy=20; aggressive policy=30
predict_year = [2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026 2027 2028 2029 2030]; % The predicted years (2017-2030)
%% Step 2: Read the SDG dataset and calcuate the past annual growth rate
year_2016 = zeros(city_n,SDG_n);
year_rate = zeros(city_n,SDG_n);
num=1;
for sheet_num = 10:26
    str =['Reading completed ' num2str(num/17*100) ' %'];
    disp(str)
    M = readmatrix('Supplementary tables 20210815.xlsx','UseExcel',1,'Sheet',sheet_num,'Range' ,[3 9 287 14]);% 'sheet':10; 'Range':numeric inputs [r1 c1 r2 c2]   
    year_2016(:,num) = M(:,6);
    for i = 1:length(M)
        tmp = (M(i,6)/M(i,1))^0.2 -1;
        if tmp < 0
            tmp = 0;
        elseif tmp > 1
            tmp =1;
        else
%             tmp = tmp;
        end
    year_rate(i,num) = 100 * tmp;
    end
    num = num+1;
end
%% Step 3: Construct the distance matrix in sustainability 
M_285 = zeros(city_n,city_n); 
for i =1:city_n
    for j =1:city_n
        temp =0;
        for k = 1:SDG_n
            if isnan(year_2016(i,k)) || isnan(year_2016(j,k)) % no SDG 14 (Marine)
                continue;
            end
            temp = temp + abs(year_2016(i,k)-year_2016(j,k)); % Calcualte the distance in sustainability
        end
        
        if isnan(year_2016(i,14)) || isnan(year_2016(j,14)) % no SDG 14 (Marine)
            M_285(i,j) = temp/16;
        else
            M_285(i,j) = temp/17;
        end
    end
end

%% Step 4: Determine the future growth rate and project the scores from 2017 to 2030
reference_city = zeros(city_n,SDG_n,length(predict_year)-1);% from year_2017 to year_2030
difficulty = zeros(city_n,SDG_n,length(predict_year)-1);% from year_2017 to year_2030
SDG_predict_year = zeros(city_n,SDG_n,length(predict_year));% the final result of the projected scores
SDG_predict_year(:,:,1) = year_2016;
for year_t = 2:length(predict_year) % from year_2017 to year_2030
    SDG_predict_year_tmp =zeros(city_n,SDG_n);
    SDG_year_before =SDG_predict_year(:,:,year_t-1);
    for i =1:city_n
      temp = M_285(i,:);
      [r,c] = find(temp <= threshold);
      year_rate_pick = zeros(length(c),SDG_n);
      if length(c)==1 % only the city itself can be considered
          maxium_year_rate = year_rate(c(1),:);
          tmp = repmat(c(1),[1 SDG_n]);
          reference_city(i,:,year_t-1) = tmp;
          tmp = repmat(M_285(i,c(1)),[1 SDG_n]);
          difficulty(i,:,year_t-1) = tmp;
      else
          city_t = 1;
          for j = 1:length(c)
              city_index = c(j);
              year_rate_pick(city_t,:)=year_rate(city_index,:);
              city_t = city_t+1;
          end 
          [maxium_year_rate, index] = max(year_rate_pick);% return a row vector containing the maximum value of each column and the index
          for k =1:SDG_n
              reference_city(i,k,year_t-1) = c(index(k));
              difficulty(i,k,year_t-1) = M_285(i,c(index(k)));
          end
      end
      SDG_predict_year_tmp(i,:) = (maxium_year_rate+100) .* SDG_year_before(i,:)/100;
    end
    SDG_predict_year_tmp(SDG_predict_year_tmp>100)=100; % constrain the maximum value at 100
    SDG_predict_year(:,:,year_t) = SDG_predict_year_tmp;
    %update 285*285 matrix
    M_285 = zeros(city_n,city_n);
    for i =1:city_n
        year_tmp = year_2016;
        year_tmp(i,:) = SDG_predict_year(i,:,year_t);% only the city itself uses predict value 
        for j =1:city_n
            temp =0;
            for k = 1:SDG_n
                if isnan(year_tmp(i,k)) || isnan(year_tmp(j,k)) % no SDG 14 (Marine)
                    continue;
                end
                temp = temp + abs(year_tmp(i,k)-year_tmp(j,k));
            end

            if isnan(year_tmp(i,14)) || isnan(year_tmp(j,14)) % no SDG 14 (Marine)
                M_285(i,j) = temp/16;
            else
                M_285(i,j) = temp/17;
            end
        end
    end
end

xlswrite('SDG_predict_year_30.xls',SDG_predict_year(:,:),'Sheet1') % Export the scores of the SDGs resutls