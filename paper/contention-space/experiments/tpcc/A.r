source("../common.r", local = TRUE)
setwd("../tpcc")
# TPC-C A: 100 warehouse, in-memory, variable threads, with/-out split&merge

rome=read.csv('./A/rome/A_rome_stats.csv')
intel=read.csv('./A/intel/GenuineIntel_stats.csv')
intel=sqldf("select * from intel where c_worker_threads <=96")
arm=read.csv('./A/arm/arm_stats.csv')

stats=sqldf("select * from rome UNION select * from intel UNION select * from arm")
d=sqldf("select c_tag, c_mutex,c_worker_threads,c_cm_split,max(tx) tx from stats group by c_worker_threads, c_cm_split,c_pin_threads, c_tag, c_mutex")
d=sqldf("
select *, 1 as type from d where c_cm_split = false and c_mutex = true
UNION
select *, 3 as type from d where c_cm_split = true and c_mutex = true
")

dev.set(0)

tx <- ggplot(d, aes(x=factor(c_worker_threads), y =tx, color=factor(type), group=factor(type))) +
    geom_point() +
    scale_x_discrete(name="worker threads") +
    scale_y_continuous(name="TPC-C throughput [txn/s]") +
    scale_color_discrete(name=NULL, labels=c("Baseline", "+Contention Split")) +
    geom_line() +
    expand_limits(y=0) +
    theme_bw() +
    facet_grid(row=vars(c_tag),col=vars(), labeller = label_both)
print(tx)

CairoPDF("./tpcc_A.pdf", bg="transparent")
print(tx)
dev.off()

speedup = sqldf("select s.c_tag, s.c_worker_threads,s.tx * 1.0 /b.tx from d s, d b where s.c_cm_split= 1 and b.c_cm_split=0 and b.c_worker_threads=s.c_worker_threads group by s.c_worker_threads, s.c_tag")
speedup

df=read.csv('./A_skx.csv')
d=sqldf("select c_worker_threads,c_cm_split,max(tx) tx from df group by c_worker_threads, c_cm_split")
tx <- ggplot(d, aes(x=factor(c_worker_threads), y =tx, color=factor(c_cm_split), group=factor(c_cm_split))) + geom_point() + scale_x_discrete(name="worker threads") + scale_y_continuous(name="TPC-C throughput [txn/s]") + scale_color_discrete(name=NULL, labels=c("baseline","+CS +EM")) + geom_line() + expand_limits(y=0) + theme_bw()
print(tx)










arm=read.csv('./A/arm/arm_old_stats.csv')
arm=sqldf("select c_pin_threads,c_worker_threads, c_cm_split,max(tx) tx from arm group by c_worker_threads, c_cm_split,c_pin_threads")
aws=read.csv('./A/aws/tpcc_a_stats.csv')
aws=sqldf("select c_pin_threads,c_worker_threads,c_cm_split,max(tx) tx from aws group by c_worker_threads, c_cm_split,c_pin_threads")
d=sqldf("select *,'m6g.16xlarge' as tag from arm union select *,'c5.18xlarge' as tag from aws")

tx <- ggplot(d, aes(x=factor(c_worker_threads), y =tx, color=factor(c_cm_split), group=factor(c_cm_split))) +
    geom_point() +
    scale_x_discrete(name="worker threads") +
    scale_y_continuous(name="TPC-C throughput 100 warehouses [txn/s]") +
    scale_color_discrete(name=NULL, labels=c("baseline","+Contention Split")) +
    geom_line() +
    expand_limits(y=0) +
    theme_bw() +
    facet_grid(row=vars(tag),col=vars())
print(tx)

CairoPDF("./arm_vs_x64.pdf", bg="transparent")
print(tx)
dev.off()

# arm 5,54009  rome 7,64342 (1 warehouse)


                                        #debug arm
old=read.csv('./A/arm/arm_old_stats.csv')


arm20=read.csv('./A/arm/arm_stats.csv')
arm18=read.csv('./A/arm/arm-ubuntu18_stats.csv')
arm=sqldf()
