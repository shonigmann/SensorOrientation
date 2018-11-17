%% Simon Honigmann
% Sensor Orientation
% Lab 7: Kalman Filtering with simulated GPS data: simple (a=0) model
% 11/16/18

%% Cleanup
clc;
clear;
close all;

%% Lab Formatting:
set(groot,'DefaultAxesFontSize',14);
set(groot,'DefaultLineLineWidth',1.5);

%% Constants
r = 25; % Circle radius: 500 m, Angular speed ? = ?/100;
omega = pi/100; % angular speed = pi/100
g = 9.81; %gravity, m/s^2
%only for 100Hz and Trapezoidal
sampling_rate = .5; %is this what is meant bz time interval?
method = 'Trapezoidal';
f = sampling_rate;
sample_rate_text = num2str(sampling_rate,3);
num_rotations = 1; %number of time the vehicle goes around the circle. increase to better show divergence

%% Assumptions/Constraints
dr = 0; %constant radius of motion in m frame
ddr = 0;
dpsi = omega; %constant angular velocity in m frame
ddpsi = 0;

%% Initial Conditions
psi_0 = 0; % Initial position: on North axis

alpha_0 = psi_0 + pi/2;
x_0 = [r,0];
dx_0 = [0,omega*r]; % Initial velocity: north-axis: 0, east-axis: ? ? radius
required_time = 2*num_rotations*pi/omega; %time for 1 full rotation [s]
t = (0:1/sampling_rate:required_time)'; %time vector, [s]
samples = (1:length(t))';

%% Generating Actual Trajectories
psi = (psi_0:num_rotations*2*pi/(length(t)-1):num_rotations*2*pi)'; %polar angle, [rad]
alpha = psi + pi/2; %azimuth angle, Initial azimuth: 90? (towards x-accelerometer)
x_m = [r*cos(psi),r*sin(psi)]; % map frame, [north, east]
dx_m = [dr.*cos(psi)-r.*sin(psi).*dpsi , r.*cos(psi).*dpsi + dr.*sin(psi)];
ddx_m = [ddr.*cos(psi) - dr.*sin(psi).*dpsi - (dr.*sin(psi).*dpsi + r.*cos(psi).*dpsi.^2 + r.*sin(psi).*ddpsi), ... %ddx_m1
    dr.*cos(psi).*dpsi - r.*sin(psi).*dpsi.^2 + r.*cos(psi).*ddpsi + ddr.*sin(psi)+dr.*cos(psi).*dpsi ]; %ddx_m2
dalpha = dpsi*ones(length(t),1); %deriving alpha wrt time = deriving psi wrt time
v_b = [ones(length(t),1)*omega*r,zeros(length(t),1)]; % got lazy... this works here because omega and r are constant. Would need to change this line if that was not the case
a_b = [zeros(length(t),1),ones(length(t),1)*omega^2*r]; %got lazy... this works here because omega and r are constant. Would need to change this line if that was not the case

%% Simulating Noisy GPS Signal
sigma_n = 0.5; % random noise of gps measurement in x direction
sigma_e = 0.5; % random noise of gps measurement in x direction

seed = 1234567;
n = length(t);
[n_gpsN,~] = whiteNoiseRandomWalk(n,seed); %generate white noise process
[n_gpsE,~] = whiteNoiseRandomWalk(n,seed+1); %generate white noise process

n_gps = [sigma_n*n_gpsN,sigma_e*n_gpsE];
gps = x_m+n_gps;

%% Kalman Filter Setup
x(:,1) = [0,0,0,0]'; % pn, pe, vn, ve
xtild = x;
xhat = x;

%uncertainty of inital measurement
sigma_x = 10;
sigma_v = 0.05;
sigma_xn = sigma_x;
sigma_vn = sigma_v;
sigma_xe = sigma_x;
sigma_ve = sigma_v;

z = zeros(4,1);%randn(1,4).*[sigma_x,sigma_x, sigma_v,sigma_v]; %initial measurement, with white noise uncertainty

F(1,:,:) = [0 0 1 0; 0 0 0 1; 0 0 0 0; 0 0 0 0]; %dynamic matrix
H = [1 0 0 0; 0 1 0 0]; %measurement design matrix
G = [0 0; 0 0; 1 0; 0 1]; %noise shaping matrix

R = [sigma_xn 0 0 0; ...
     0 sigma_xe 0 0; ...
     0 0 sigma_vn 0;...
     0 0 0 sigma_ve]; %covariance of measurement noise

%NOT SURE ABOUT THIS????
dq_vn = 0.05;
dq_ve = 0.05;
dt = 2; % time step used in prediction
Qk(1,:,:) = [1/3*dt^3*dq_vn, 0 ,1/2*dt^2*dq_vn, 0;...
      0, 1/3*dt^3*dq_ve, 0 ,1/2*dt^2*dq_ve; ...
      1/2*dt^2*dq_vn, 0,dt*dq_vn, 0; ...
      0, 1/2*dt^2*dq_ve, 0, dt*dq_ve]; %covariance matrix of the system noise

P = ; %covariance of state estimate
%Phat = P; % a posteriori covariance of state estimate (after measurement)
Ptild = P; % a priori covariance of state estimate (before measurement)

I = eye(size(P));
  
%% Kalman Filter Loop
%try different prediction deltaT and update deltaT
for k=1:n
   
    %prediction:
    xtild(:,k+1)=squeeze(F(k,:,:))*xhat(:,k);
    Ptild(k+1,:,:) = squeeze(F(k,:,:))*P(k,:,:)*squeeze(F(k,:,:))'+Qk(k,:,:);
    
    %calculate kalman gain
    %%CHECK IF Ptild SHOULD USE K or K+1 HERE!!!!!!!!!!!!!! EG WHEN DOES
    %%TIME UPDATE ACTUALLY HAPPEN
    K(k,:,:) = Ptild(k,:,:)*H(k,:,:)*(H(k,:,:)*Ptild(k,:,:)*H(k,:,:)+R(k,:,:));
    
    %update state
    xhat(k,:) = xtild(k,:)+K(k,:,:)*(z(k,:)-H(k,:,:)*xtild(k,:));
    
    %%CHECK IF Ptild SHOULD USE K or K+1 HERE!!!!!!!!!!!!!!
    %update covariance
    P(k+1,:,:) = (I-K(k,:,:)*H(k,:,:))*Ptild(k,:,:);
    
end

%% Plotting Trajectories
figure(k);
%position
subplot(2,1,1);
plot(x_m(:,2),x_m(:,1));
hold on;
xlabel('X_m_2, East (m)');
ylabel('X_m_1, North (m)');
title(['True vs Estimate Position (',method,' Integration, ',sample_rate_text,'Hz)']);
plot(x_sd(:,2),x_sd(:,1));
axis('equal');
legend('True',strcat(method,', ',sample_rate_text,'Hz'));

%% Calculate Errors

%% PLOTS REQUIRED: 2x1 subplot with position measurements (ref, meas, KF) and error (meas, KF)
%%               : 2x1 subplot with velocitz measurements (ref, KF) and error (KF)
%%               : Histogram innovation histogram for north and east

%% Plotting Errors
%position
subplot(2,1,2);
plot(t,err_x(:,1));
hold on;
plot(t,err_x(:,2));
plot(t,err_x(:,3));
xlabel('Time (s)');
ylabel('X_m Error (m)');
title(['Position Error Over Time (',method,' Integration, ',sample_rate_text,'Hz)']);
legend('North','East','Error Magnitude');