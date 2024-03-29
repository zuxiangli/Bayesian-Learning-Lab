library(mvtnorm)
library(extraDistr)
library(ggplot2)
# 1a
data=read.table("lab3/rainfall.dat")

x_mean=mean(data[,1])
n=length(data[,1])

# for mu
# set sigma to 1


# for sigma


params=data.frame()

sigma_sq=1
tau_0_sq=1
mu_0=mean(data[,1])

v_0=1
sigma_0_sq=var(data[,1])
#sigma_0_sq=(v_0*sigma_0_sq+sum(data[,1]-mu)^2)/(n+v_0)
for(i in 1:1000){
  # update mu
  w=(n/sigma_sq)/((n/sigma_sq)+(1/tau_0_sq))
  tau_n_sq=1/(n/sigma_sq+1/tau_0_sq)
  mu_n=w*x_mean+(1-w)*mu_0
  mu=rnorm(1,mu_n,tau_n_sq)
  
  # update sigma
  v_n=v_0+n
  X=rchisq(1,n-1)
  sigma_sq=(n-1)*sum((data[,1]-x_mean)^2)/(n)/X
  # sigma_0_sq=(v_0*sigma_0_sq+sum(data[,1]-mu)^2)/(n+v_0)
  # sigma_sq=v_n*rinvchisq(1,nu=v_n,tau=sigma_0_sq)/sigma_0_sq
  # 
  tmp=data.frame(mu=mu,sigma_sq=sigma_sq)
  params=rbind(params,tmp)
}

plot(params$mu)
hist(params$mu)
plot(params$sigma_sq)
hist(params$sigma,breaks=100)


# 1b
data=read.table("lab3/rainfall.dat")
#rawData <- faithful
#x <- as.matrix(rawData['eruptions'])
x=as.matrix(data)
# Model options
nComp <- 2    # Number of mixture components

# Prior options
alpha <- 10*rep(1,nComp) # Dirichlet(alpha)
muPrior <- rep(0,nComp) # Prior mean of mu
tau2Prior <- rep(1,nComp) # Prior std of mu
sigma2_0 <- rep(var(x),nComp) # s20 (best guess of sigma2)
nu0 <- rep(1,nComp) # degrees of freedom for prior on sigma2

# MCMC options
nIter <- 100 # Number of Gibbs sampling draws

# Plotting options
plotFit <- TRUE
lineColors <- c("blue", "green", "magenta", 'yellow')
sleepTime <- 0.1 # Adding sleep time between iterations for plotting
################   END USER INPUT ###############

###### Defining a function that simulates from the 
rScaledInvChi2 <- function(n, df, scale){
  return((df*scale)/rchisq(n,df=df))
}

####### Defining a function that simulates from a Dirichlet distribution
rDirichlet <- function(param){
  nCat <- length(param)
  piDraws <- matrix(NA,nCat,1)
  for (j in 1:nCat){
    piDraws[j] <- rgamma(1,param[j],1)
  }
  piDraws = piDraws/sum(piDraws) # Diving every column of piDraws by the sum of the elements in that column.
  return(piDraws)
}

# Simple function that converts between two different representations of the mixture allocation
S2alloc <- function(S){
  n <- dim(S)[1]
  alloc <- rep(0,n)
  for (i in 1:n){
    alloc[i] <- which(S[i,] == 1)
  }
  return(alloc)
}

# Initial value for the MCMC
nObs <- length(x)
S <- t(rmultinom(nObs, size = 1 , prob = rep(1/nComp,nComp))) # nObs-by-nComp matrix with component allocations.
mu <- quantile(x, probs = seq(0,1,length = nComp))
sigma2 <- rep(var(x),nComp)
probObsInComp <- rep(NA, nComp)

# Setting up the plot
xGrid <- seq(min(x)-1*apply(x,2,sd),max(x)+1*apply(x,2,sd),length = 100)
xGridMin <- min(xGrid)
xGridMax <- max(xGrid)
mixDensMean <- rep(0,length(xGrid))
effIterCount <- 0
ylim <- c(0,2*max(hist(x)$density))

params=data.frame()
for (k in 1:100){
  message(paste('Iteration number:',k))
  alloc <- S2alloc(S) # Just a function that converts between different representations of the group allocations
  nAlloc <- colSums(S)
  print(nAlloc)
  # Update components probabilities
  pi <- rDirichlet(alpha + nAlloc)
  
  # Update mu's
  for (j in 1:nComp){
    precPrior <- 1/tau2Prior[j]
    precData <- nAlloc[j]/sigma2[j]
    precPost <- precPrior + precData
    wPrior <- precPrior/precPost
    muPost <- wPrior*muPrior + (1-wPrior)*mean(x[alloc == j])
    tau2Post <- 1/precPost
    mu[j] <- rnorm(1, mean = muPost, sd = sqrt(tau2Post))
  }
  tmp=data.frame(mu1=mu[1],mu2=mu[2])
  # Update sigma2's
  for (j in 1:nComp){
    sigma2[j] <- rScaledInvChi2(1, df = nu0[j] + nAlloc[j], scale = (nu0[j]*sigma2_0[j] + sum((x[alloc == j] - mu[j])^2))/(nu0[j] + nAlloc[j]))
  }
  tmp$sigma2_1=sigma2[1]
  tmp$sigma2_2=sigma2[2]
  params=rbind(params,tmp)
  # Update allocation
  for (i in 1:nObs){
    for (j in 1:nComp){
      probObsInComp[j] <- pi[j]*dnorm(x[i], mean = mu[j], sd = sqrt(sigma2[j]))
    }
    S[i,] <- t(rmultinom(1, size = 1 , prob = probObsInComp/sum(probObsInComp)))
  }
  
  # Printing the fitted density against data histogram
  if (plotFit && (k%%1 ==0)){
    effIterCount <- effIterCount + 1
    hist(x, breaks = 20, freq = FALSE, xlim = c(xGridMin,xGridMax), main = paste("Iteration number",k), ylim = ylim)
    mixDens <- rep(0,length(xGrid))
    components <- c()
    for (j in 1:nComp){
      compDens <- dnorm(xGrid,mu[j],sd = sqrt(sigma2[j]))
      mixDens <- mixDens + pi[j]*compDens
      lines(xGrid, compDens, type = "l", lwd = 2, col = lineColors[j])
      components[j] <- paste("Component ",j)
    }
    mixDensMean <- ((effIterCount-1)*mixDensMean + mixDens)/effIterCount
    
    lines(xGrid, mixDens, type = "l", lty = 2, lwd = 3, col = 'red')
    legend("topleft", box.lty = 1, legend = c("Data histogram",components, 'Mixture'), 
           col = c("black",lineColors[1:nComp], 'red'), lwd = 2)
    Sys.sleep(sleepTime)
  }
  
}

ggplot(data=params)+geom_line(aes(x=seq(1:100),y=mu1,colour="mu1"))+geom_line(aes(x=seq(1:100),y=mu2,colour="mu2"))
ggplot(data=params)+geom_line(aes(x=seq(1:100),y=sigma2_1,colour="mu1"))+geom_line(aes(x=seq(1:100),y=sigma2_2,colour="mu2"))
hist(x, breaks = 20, freq = FALSE, xlim = c(xGridMin,xGridMax), main = "Final fitted density")
lines(xGrid, mixDensMean, type = "l", lwd = 2, lty = 4, col = "red")
lines(xGrid, dnorm(xGrid, mean = mean(x), sd = apply(x,2,sd)), type = "l", lwd = 2, col = "blue")
legend("topright", box.lty = 1, legend = c("Data histogram","Mixture density","Normal density"), col=c("black","red","blue"), lwd = 2)

# 2
data=read.table("lab3/eBayNumberOfBidderData.dat",header = TRUE)
data1=data[,-2]

glm_mod=glm(nBids~.,data=data1,family=poisson())
glm_mod$coefficients
response=data1[,1]
covariates=data1[,-1]
covariates=as.matrix(covariates)
response=as.matrix(response)
p=dim(covariates)[2]
n=dim(covariates)[1]



response=data[,1]
covariates=data[,-1]
covariates=as.matrix(covariates)
response=as.matrix(response)
p=dim(covariates)[2]
n=dim(covariates)[1]

log_likehood_poisson=function(y,x,betas){
  log_likelihood=vector(length = n)
  for(i in 1:n){
    log_likelihood[i]=y[i]*betas%*%x[i,]-exp(betas%*%x[i,])-log(factorial(y[i]))
  }
  return(sum(log_likelihood))
}

log_prior_likelihood=function(betas){
  mu=rep(0,p)
  sigma_sq=100*solve(t(covariates)%*%covariates)
  log_likelihood=(log(det(sigma_sq))+t(betas-mu)%*%solve(sigma_sq)%*%(betas-mu)+p*log(2*pi))*0.5
  return(log_likelihood)
}

# for log posterior= log prior +log likelihood
log_posterior=function(betas,y,x){
  #return(log_likelihood_probit(y,x,betas)+log_prior_likelihood(tau,betas))
  return(log_likehood_poisson(y,x,betas)+log_prior_likelihood(betas))
}

starting_value=rep(0,p)
op=optim(starting_value,log_posterior,gr=NULL,response,covariates,method=c("BFGS"),control=list(fnscale=-1),hessian=TRUE)
posterior_mode=op$par
posterior_cov=-solve(op$hessian)


log_likehood_poisson=function(y,x,betas){
  log_likelihood=vector(length = n)
  for(i in 1:n){
    log_likelihood[i]=y[i]*betas%*%x[i,]-exp(betas%*%x[i,])-log(factorial(y[i]))
  }
  return(sum(log_likelihood))
}

log_posterior=function(y,x,theta_p,previous_theta,sigma,first=FALSE){
  if(first==TRUE){
    return(log_likehood_poisson(y,x,theta_p))
  }else{
    return(log_likehood_poisson(y,x,theta_p)+dmvnorm(theta_p,mean=previous_theta,sigma=posterior_cov,log = TRUE))
  }
}
# RWM algorithm
RWMSampler=function(c,y,x,maxit,log_posterior,...){
  theta_series=matrix(nrow = maxit,ncol=p)
  theta_series[1,]=rep(0,p)
  theta_logs=vector(length = maxit)
  theta_logs[1]=log_posterior(y,x,theta_series[1,],first = TRUE)
  for(i in 2:maxit){
    u=runif(1)
    # sample from proposal
    theta_p=rmvnorm(1,mean=theta_series[i-1,],sigma=c*posterior_cov)

    current_log_d=log_posterior(y=y,x=x,theta_p=theta_p,previous_theta=theta_series[i-1,],sigma=c*posterior_cov)

    alpha=min(1,exp(current_log_d-theta_logs[i-1]))
    if(u<alpha){
      theta_series[i,]=theta_p
      theta_logs[i]=current_log_d
      
    }else{
      theta_series[i,]=theta_series[i-1,]
      theta_logs[i]=theta_logs[i-1]
    }
  }
  return(list(theta_series=theta_series,theta_logs=theta_logs))
  
}
ddd=RWMSampler(1.3,response,covariates,maxit=10000,log_posterior)
tmp=ddd$theta_series
plot(ddd$theta_series[,9])
ddd$theta_series[10000,]
colMeans(tmp)
# # init
# RWMSampler=function(x,y,maxit){
#   theta_series=matrix(nrow = maxit,ncol=p)
#   theta_series[1,]=rep(0,p)
#   theta_logs=vector(length = maxit)
#   theta_logs[1]=log_likehood_poisson(y,x,theta_series[1,])+1
#   for(i in 2:maxit){
#     print(i)
#     u=runif(1)
#     # sample from proposal
#     theta_p=rmvnorm(1,mean=theta_series[i-1,],sigma=posterior_cov)
#     #print("theta_p")
#     log_llik=log_likehood_poisson1(y,x,theta_p)
#     #print("log_llik")
#     log_pr=dmvnorm(theta_p,mean=theta_series[i-1,],sigma=posterior_cov,log = TRUE)
#     #print("logpr")
#     current_log_d=log_llik+log_pr
#     alpha=min(1,exp(current_log_d-theta_logs[i-1]))
#     if(u<alpha){
#       theta_series[i,]=theta_p
#       theta_logs[i]=current_log_d
# 
#     }else{
#       theta_series[i,]=theta_series[i-1,]
#       theta_logs[i]=theta_logs[i-1]
#     }
#   }
#   return(list(theta_series=theta_series,theta_logs=theta_logs))
# }




new_bidder=matrix(c(1,1,1,1,0,0,0,1,0.5),nrow = 1)
#co=as.matrix(ddd$theta_series[10000,])
co=as.matrix(colMeans(tmp))
dim(new_bidder)
dim(co)

pred=vector(length=10000)
for(i in 1:10000){
  pred[i]=rpois(1,exp(new_bidder%*%co))
}
hist(pred)
# log posterior = log likelihood + log prior
# 
# n=1:1000
# series=matrix(nrow = 1000,ncol=p)
# series[1,]=rep(0,p)
# for(i in 2:1000){
#   previous_theta=series[i-1,]
#   new_theta=rmvnorm(1,mean=previous_theta,sigma = posterior_cov)
#   u=runif(1)
# 
#   # to get p(theta_p) and p(theta_i-1)
#   p_new_theta=dmvnorm(new_theta,mean=previous_theta,sigma=posterior_cov)
#   if(i==2){
#     p_previous_theta=1
#   }else{
#     p_previous_theta=dmvnorm(previous_theta,mean=series[i-2,],sigma=posterior_cov)
#   }
#   # for p(y|theta_p) and p(y|theta_i-1)
#   p_y_theta_p=vector(length=1000)
#   p_y_theta_i_1=vector(length=1000)
#   for(i in 1:1000){
#     new_lambda=exp(covariates[i,]%*%t(new_theta))
#     previous_lambda=exp(covariates[i,]%*%t(previous_theta))
#     p_y_theta_p[i]=dpois(response[i],new_lambda)
#     p_y_theta_i_1[i]=dpois(response[i],previous_lambda)
#   }
#   prob=exp(sum(log(p_y_theta_p))+log(p_new_theta)-sum(log(p_y_theta_i_1))-log(p_previous_theta))
#   #prob=exp(log(prod(p_y_theta_p)*p_new_theta)-log(prod(p_y_theta_i_1)*p_previous_theta))
#   print(prob)
#   alpha=min(1,prob)
#   if(u<alpha){
#     series[i,]=new_theta
#   }else{
#     series[i,]=previous_theta
#   }
# }
# t=rmvnorm(1,mean=rep(0,p),sigma = 100*posterior_cov)
# dmvnorm(t,mean=rep(0,p),sigma = 100*posterior_cov)
# 
# for(i in 1:1000){
#   lambda=exp(t(covariates[i,])%*%rep(1,p))
#   print(dpois(response[i],lambda))
# }
# 
# 
# rpois(1,)