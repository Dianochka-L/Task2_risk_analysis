-- Так как SQL команды требовались в тексте задания, я прописала, хотя больше люблю пандас )
--количество заявок по источникам
select source,
       count(*) as cnt_apps
from spr_application
group by source;

-- проверка структуры данных)
select request_type,
       status,
       count(*) as cnt
from spr_request
group by request_type, status
order by request_type, status;

-- Текущий уровень одобрения Одобрено = FULL_APPLICATION / APPROVE
select count(*)                                          as total_applications,
       sum(case when r.request_type = 'FULL_APPLICATION'
                 and r.status = 'APPROVE'
                then 1 else 0 end)                       as approved,
       round(100.0 * sum(case when r.request_type = 'FULL_APPLICATION'
                               and r.status = 'APPROVE'
                              then 1 else 0 end)
             / count(distinct a.application_id), 2)      as approval_rate_pct
from spr_application a
left join spr_request r
       on r.application_id = a.application_id;



-- Витрина заявок, дошедших до FULL_APPLICATION, с признаком ПВ
select a.application_id,
       a.source,
       f.dti,
       f.pd,
       f.initinal_payment as pv,
       r.status as current_status
from spr_request r
join spr_application a on a.application_id = r.application_id
join spr_features f on f.id = r.spr_features_id
where r.request_type = 'FULL_APPLICATION';

-- Распределение ПВ у текущих ОДОБРЕННЫХ заявок относительно порога
select case when f.initinal_payment >= 0.32 then 'PV >= 0.32 (низкий риск)'
            else 'PV < 0.32 (повышенный риск)' end as pv_bucket,
       count(*) as cnt
from spr_request r
join spr_features f on f.id = r.spr_features_id
where r.request_type = 'FULL_APPLICATION' and r.status = 'APPROVE'
group by case when f.initinal_payment >= 0.32 then 'PV >= 0.32 (низкий риск)'
              else 'PV < 0.32 (повышенный риск)' end;

-- одобрение после добавления правила ПВ >= 0.32
-- Правило работает как дополнительный отсекающий фильтр на шаге
--заявка одобряется, только если текущий статус APPROVE И ПВ >= порога
select count(distinct a.application_id) as total_applications,
       sum(case when r.request_type = 'FULL_APPLICATION'
                 and r.status = 'APPROVE'
                then 1 else 0 end) as approved_before,
       sum(case when r.request_type = 'FULL_APPLICATION'
                 and r.status = 'APPROVE'
                 and f.initinal_payment >= 0.32
                then 1 else 0 end) as approved_after,
       round(100.0 * sum(case when r.request_type = 'FULL_APPLICATION'
                               and r.status = 'APPROVE'
                              then 1 else 0 end)
             / count(distinct a.application_id), 2) as approval_before_pct,
       round(100.0 * sum(case when r.request_type = 'FULL_APPLICATION'
                               and r.status = 'APPROVE'
                               and f.initinal_payment >= 0.32
                              then 1 else 0 end)
             / count(distinct a.application_id), 2) as approval_after_pct
from spr_application a
left join spr_request r on r.application_id = a.application_id
left join spr_features f on f.id = r.spr_features_id;


-- заявки, отклоненные на FULL_APPLICATION, но с высоким ПВ (>= 0.32)... кандидаты на пересмотр правил
select count(*) as declined_but_low_risk
from spr_request  r
join spr_features f on f.id = r.spr_features_id
where r.request_type = 'FULL_APPLICATION'
  and r.status = 'DECLINE'
  and f.initinal_payment >= 0.32;

select a.source,
       sum(case when r.status = 'APPROVE' then 1 else 0 end) as approved_before,
       sum(case when r.status = 'APPROVE'
                 and f.initinal_payment >= 0.32 then 1 else 0 end) as approved_after
from spr_request r
join spr_application a on a.application_id = r.application_id
join spr_features f on f.id = r.spr_features_id
where r.request_type = 'FULL_APPLICATION'
group by a.source
order by a.source;