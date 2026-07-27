package com.walkingrpg.backend.risk.infrastructure;

import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;

public interface ActivityRiskRepository {

    void save(ActivityRiskAssessment assessment);
}
