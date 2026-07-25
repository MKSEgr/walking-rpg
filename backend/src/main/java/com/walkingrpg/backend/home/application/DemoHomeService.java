package com.walkingrpg.backend.home.application;

import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import org.springframework.stereotype.Service;

@Service
public class DemoHomeService {

    public HomeSnapshotResponse getDemoSnapshot() {
        PilotSnapshot pilot = new PilotSnapshot(
                "Навигатор",
                1,
                20,
                100,
                "Не выбрана"
        );

        PetSnapshot pet = new PetSnapshot(
                "Искра",
                "Люмин",
                1,
                10,
                "Чуткий разведчик"
        );

        ExpeditionSnapshot expedition = new ExpeditionSnapshot(
                "Сигнал из туманного сектора",
                "Внешний маяк",
                0,
                30
        );

        return new HomeSnapshotResponse(
                0,
                6_000,
                0,
                pilot,
                pet,
                expedition
        );
    }
}
