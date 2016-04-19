%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
trials = 150;
x = zeros(3*trials,1);
for j=1:3
    for i=1:trials
        number = randi(9,1);
        x(i+(j-1)*trials,1) = number;
    end
end

autocor = zeros(40,1);
for lag=1:40
dx = circshift(x,lag);
autocor(lag,1) = sum(x.*dx);
end
figure;
plot(autocor);


