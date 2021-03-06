### Example workflow of `lotR`
### Zhenke Wu | zhenkewu@gmail.com
### August 04, 2020
### This example has true parameters following the tree structured priors.
rm(list=ls())
library(lotR)

data("lotR_example_edges")
library(igraph)
tr <- graph_from_edgelist(lotR_example_edges, directed = TRUE) # Plot tree
# Here in this example, we use equal weighted edges.

# If needed, first install ggtree
# if (!requireNamespace("BiocManager", quietly = TRUE))
# install.packages("BiocManager")
# BiocManager::install("ggtree")
library(ggtree)
library(ggplot2)
ggtree(tr, ladderize = FALSE, layout = "slanted") +
  geom_tiplab(geom = "label") + geom_nodelab(geom = "label") +
  theme(plot.margin = unit(c(0, 1.5, 0, 0.2), "cm")) +
  coord_cartesian(clip = "off") + scale_y_reverse()

leaves <- names(igraph::V(tr)[degree(tr, mode = "out") == 0])

# set levels: leaves 2, non-leaves 1
igraph::V(tr)$levels <- rep(1,length(igraph::V(tr)))
igraph::V(tr)$levels[match(names(igraph::V(tr)[igraph::degree(tr, mode = "out") == 0]),
                   names(igraph::V(tr)))] <- 2

igraph::E(tr)$weight <- rep(1,length(E(tr)))
###############################################################################
## illustration of lotR on simulated data:
###############################################################################
data("lotR_example_data_tree") # assumes a single pi for all observations.
Y     <- lotR_example_data_tree$Y
Z_obs <- lotR_example_data_tree$Z_obs
curr_leaves <- lotR_example_data_tree$curr_leaves
theta <- lotR_example_data_tree$truth$itemprob
pi_mat <- lotR_example_data_tree$truth$pi_mat
# in the simulation, the 1st class has the highest level of probabilities,
# so we will reorder obtained estimates to match the meaning of classes.
Z     <- lotR_example_data_tree$truth$Z

## check if all leave names are present in the data.
setequal(leaves, unique(curr_leaves))
#> [1] TRUE
knitr::kable(table(curr_leaves))

K     <- nrow(theta)
p     <- length(V(tr))
J     <- ncol(Y)

dsgn0  <- design_tree(Y,curr_leaves,tr,weighted_edge = FALSE,Z_obs)

nrestarts <- 1
# doParallel::registerDoParallel(cores = nrestarts)
# log_dir <- tempdir()
# dir.create(log_dir)
set.seed(345083)
par(mfrow=c(3,3));plot(0,0)
mod0     <- lcm_tree(Y,curr_leaves,tr,
                     weighted_edge = !TRUE,
                     Z_obs         = Z_obs,
                     parallel      = TRUE,
                     hyper_fixed   = list(K=K,a=c(1,1),b=c(1,1),
                                          tau_update_levels = c(1,2),
                                          # should this be set as default?
                                          s_u_zeroset = NULL,
                                          s_u_oneset = c(1)),
                     # hyperparams_init = list(tau_1=matrix(9/4,nrow=2,ncol=K-1),
                     #                         tau_2=array(9/4,c(2,J,K))),
                     vi_params_init = list(prob=rep(0.95,p)),
                     random_init = !TRUE,
                     nrestarts     = nrestarts,
                     quiet         = !TRUE,
                     plot_fig      = TRUE,
                     shared_tau    = FALSE,
                     get_lcm_by_group = TRUE, #<--- check what are the prereq.
                     print_freq    = 10,update_hyper_freq = 50, max_iter = 200,
                     tol           = 1e-7,
                     tol_hyper     = 1e-4,
                     allow_continue = FALSE)#,
#log_restarts =!TRUE,
#log_dir = log_dir)

###############################################################################
# print out summaries of group specific estimates:
###############################################################################
# plot(mod0,layout = "slanted", horizontal = FALSE)
plot(mod0)

print(mod0)

which(mod0$mod$vi_params$prob>0.5)
unique(lotR_example_data_tree$truth$pi_mat)

###############################################################################
# print out performance metrics (only possible when doing simulation)
###############################################################################
res <- mod0

#------------------------------------------------#
#  estimates based on data-driven leaf groups.
#------------------------------------------------#

# 1. RMSE
## truth vs grouped:
# prob_est is with node_select (grouped estimates). NB: need to do individual
# leaf estimates.
# permute the estimated classes to best match the truth in terms of the response
# probability profiles.
itemprob_truth   <- t(lotR_example_data_tree$truth$itemprob)
itemprob_est     <- res$prob_est$theta_collapsed
# we set prob_gamma to be all zero except for the root node;
# so theta_collapsed is just the shared response probability profiles.
permute_est      <- opt_colpermB(itemprob_truth,itemprob_est)
# permute estimated classes to best match truth.

A <- lotR_example_data_tree$truth$pi_mat # leaf level; in truth,
                                       # we have group structure.
B <- res$prob_est$pi[,permute_est,drop=FALSE] #leaf level

rmse_bias_grp <- rmse_bias_AB(A,B)
print(rmse_bias_grp)

## Do the above for separate ad hoc estimates.

# 2. adjusted Rand index (aRI):
true_grouping <- factor(apply(A,1,paste,collapse=""),
                        levels = unique(apply(A,1,paste,collapse="")))
# the true grouping labels are following the order with
# which the leaf nodes were coded in the tree.

# mclust::adjustedRandIndex(true_grouping,res$prob_est$group)

# 3. misclassification
Az <- lotR_example_data_tree$truth$Z
Bz <- apply(res$mod$vi_params$rmat[,permute_est,drop=FALSE],1,which.max)
table(Az,Bz)
sum((Az!=Bz)/length(Az)) # misclassification rate

# 4. coverage (conditional: need to decide if a true group is in the estimated groups)
gtab <- table(true_grouping,res$prob_est$group)
# get the total number of estimated groups:
G <- nrow(gtab)
for (g in 1:G){# for each true group
  if (sum(gtab[g,]>0)==1){ # # did true group get split into multiple estimated groups?
    # if No...
    h <- as.integer(which(gtab[g,]>0)) # which estimated group contains
    # all leaf nodes in true group g:
    if (sum(gtab[,h]>0)==1){ # does this estimated group contain other
      # leaf nodes, not in true group g:
      # if no, then true group g and estimated group h are identical.
      # Proceed with estimating coverage.

      # Did the lotR estimate cover the truth?
      interval_est <- summary(res)[[h]]$est[permute_est,,drop=FALSE]
      v <-  which(as.integer(true_grouping)==g)[1] # pick a leaf node in the group.
      true_curr <- lotR_example_data_tree$truth$pi_mat[v,]
      covered <- (true_curr >= interval_est[,"cil_pi"]) &
        (true_curr <= interval_est[,"ciu_pi"])

      # Did the ad hoc group-specific LCM cover the truth?
      # NB: this is not done yet; we have point estimates,
      # but not yet extracted the posterior sd yet.
      cat("True Group: ", g, "\n")
      print(data.frame(truth = round(lotR_example_data_tree$truth$pi_mat[v,],3),
                       covered=covered))
      cat("----------\n")
    }
  }

}


#--------------------------------------#
# Individual leaf nodes estimates.
#--------------------------------------#

# 1. RMSE
## truth vs individual nodes:
## no node_select - the leaf nodes have distinct estimates of the pie

A <- lotR_example_data_tree$truth$pi_mat # leaf level; in truth,
                                         # we have group structure.
B <-  res$prob_est_indiv$pi[,permute_est,drop=FALSE] #leaf level

rmse_bias_indiv <- rmse_bias_AB(A,B)
print(rmse_bias_indiv)






#
# K = 2; simulate data
#

# # This code is not designed as an example for a particular function,
# # but it simulates the example data set: lotR_example_data_tree_K2
# ## This is the code for fixing K=2 issues.
#
# rm(list=ls())
# library(igraph)
# set.seed(2020)
# n = 3000
# tau   <- c(0.7,0.3)
# itemprob <- rbind(rep(rep(c(0.9, 0.9), each = 1),9),
#                   rep(rep(c(0.1, 0.1), each = 1),9))
#
# data("lotR_example_edges")
# mytree <- igraph::graph_from_edgelist(lotR_example_edges, directed = TRUE)
# # Plot tree
#
# nodes  <- names(igraph::V(mytree))
# leaves <- names(igraph::V(mytree)[degree(mytree, mode = "out") == 0])
# pL = length(leaves)
# p  = length(igraph::V(mytree))
#
# ######
# K = nrow(itemprob)
# # specify the nodes that have non-trivial alpha_u, this was called
# # xi_u, because xi_u = s_u*alpha_u and s_u = 1 if we set it in the simulation.
# alpha_mat = rbind(logit(prob2stick(tau)[-K]),
#                   c(-1),
#                   c(1),
#                   matrix(0,nrow=p-3,ncol=K-1)
# )
#
# # get lists of ancestors for each leaf_ids:
# d <- igraph::diameter(mytree,weights=NA)
# # need to set weight=NA to prevent the use of edge lengths in determining the diameter.
# ancestors <- igraph::ego(mytree, order = d + 1, nodes = leaves, mode = "in")
# ancestors <- sapply(ancestors, names, simplify = FALSE)
# ancestors <- sapply(ancestors, function(a, nodes) which(nodes %in% a),
#                     nodes = nodes, simplify = FALSE)
# names(ancestors) <- leaves
#
# # calculate the class probabilities for all leaf nodes; each leaf node
# # should have a K-dim vector that sums to one; Some nodes may share
# # the same set of K-dim probability vector, others may differ. There are
# # one or more groups of leaf nodes with distinct K-dim probability vectors.
# # Note the branch lengths may also be used here.
# pi_mat <- matrix(NA,nrow=pL,ncol=K)
# for (v in seq_along(leaves)){
#   pi_mat[v,-K] <- colSums(alpha_mat[ancestors[[v]],,drop=FALSE])
#   pi_mat[v,] <- tsb(c(expit(pi_mat[v,-K]),1))
# }
#
# # s = c(1, 1,1,0,0, rep(0,pL)) # effective nodes
# h_pau = rep(1,p)
#
# lotR_example_data_tree <- simulate_lcm_tree(n,itemprob,mytree,pi_mat,h_pau)
# table(lotR_example_data_tree$truth$Z)
#
# #save the simulated data to the R package for illustration:
# save(lotR_example_data_tree, file = "data/lotR_example_data_tree_K2.rda", compress = "xz")

